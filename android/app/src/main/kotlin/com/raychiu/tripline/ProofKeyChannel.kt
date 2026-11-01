package com.raychiu.tripline

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executors

/** DPoP 金鑰的純轉換（不碰 Keystore，可在 JVM 單獨驗證）。 */
internal object ProofKeyCodec {
    /** 公鑰座標 → 固定 32 bytes（big-endian，去掉 BigInteger 的正負號位元組）。 */
    fun coordinate(value: BigInteger): ByteArray {
        val raw = value.toByteArray()
        val trimmed = if (raw.size > 32 && raw[0] == 0.toByte()) raw.copyOfRange(1, raw.size) else raw
        require(trimmed.size <= 32) { "coordinate too large" }
        return ByteArray(32 - trimmed.size) + trimmed
    }

    /** ECDSA 的 DER 簽章（SEQUENCE { INTEGER r, INTEGER s }）→ ES256 要的 r‖s 共 64 bytes。 */
    fun rawSignature(der: ByteArray): ByteArray? {
        var index = 0

        fun readLength(): Int? {
            if (index >= der.size) return null
            val first = der[index++].toInt() and 0xff
            if (first < 0x80) return first
            val count = first and 0x7f
            if (count < 1 || count > 2 || index + count > der.size) return null
            var value = 0
            repeat(count) { value = (value shl 8) or (der[index++].toInt() and 0xff) }
            return value
        }

        fun readInteger(): ByteArray? {
            if (index >= der.size || der[index] != 0x02.toByte()) return null
            index++
            val length = readLength() ?: return null
            if (index + length > der.size) return null
            var value = der.copyOfRange(index, index + length)
            index += length
            while (value.size > 1 && value[0] == 0.toByte()) value = value.copyOfRange(1, value.size)
            if (value.size > 32) return null
            return ByteArray(32 - value.size) + value
        }

        if (der.isEmpty() || der[0] != 0x30.toByte()) return null
        index = 1
        readLength() ?: return null
        val r = readInteger() ?: return null
        val s = readInteger() ?: return null
        return r + s
    }
}

/**
 * DPoP 硬體金鑰（ADR-0015）：P-256 私鑰在 Android Keystore（可用時 StrongBox）內產生，
 * 不可匯出、不備份；不要求 user authentication，裝置解鎖即可簽。
 * 金鑰只落在軟體 Keystore（模擬器等）時一律回 `unsupported`，由 Dart 端退回軟體金鑰。
 */
class ProofKeyChannel : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> runAsync(result, "unsupported") { create() }
            "load" -> runAsync(result, "key_unavailable") { load() }
            "sign" -> {
                val data = call.argument<ByteArray>("data")
                if (data == null) {
                    result.error("no_key", "missing data", null)
                } else {
                    runAsync(result, "sign_failed") { sign(data) }
                }
            }
            "delete" -> runAsync(result, "delete_failed") {
                deleteKey()
                null
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        executor.shutdown()
    }

    /**
     * 所有操作都在同一條背景執行緒依序執行：StrongBox 產生金鑰可能數秒，不佔主執行緒；
     * 也避免 delete 與進行中的 sign／create 互踩。
     */
    private fun runAsync(result: MethodChannel.Result, errorCode: String, block: () -> Any?) {
        executor.execute {
            val outcome = runCatching(block)
            mainHandler.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error(errorCode, it.message, null) },
                )
            }
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun deleteKey() {
        runCatching { keyStore().deleteEntry(ALIAS) }
    }

    private fun generate(strongBox: Boolean): KeyPair {
        val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .apply {
                if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    setIsStrongBoxBacked(true)
                }
            }
            .build()
        return KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE)
            .apply { initialize(spec) }
            .generateKeyPair()
    }

    private fun isHardwareBacked(key: PrivateKey): Boolean {
        val info = KeyFactory.getInstance(key.algorithm, KEYSTORE)
            .getKeySpec(key, KeyInfo::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            info.securityLevel != KeyProperties.SECURITY_LEVEL_SOFTWARE
        } else {
            @Suppress("DEPRECATION")
            info.isInsideSecureHardware
        }
    }

    private fun point(publicKey: ECPublicKey): Map<String, String> = mapOf(
        "x" to base64Url(ProofKeyCodec.coordinate(publicKey.w.affineX)),
        "y" to base64Url(ProofKeyCodec.coordinate(publicKey.w.affineY)),
    )

    private fun base64Url(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    /** 建立失敗或只落在軟體 Keystore 都丟例外（Dart 端據此退回軟體金鑰）。 */
    private fun create(): Map<String, String> {
        try {
            deleteKey()
            // 先試 StrongBox；沒有或失敗就用一般（TEE）Keystore。
            val pair = try {
                generate(strongBox = true)
            } catch (e: Exception) {
                deleteKey()
                generate(strongBox = false)
            }
            check(isHardwareBacked(pair.private)) { "software keystore" }
            return point(pair.public as ECPublicKey)
        } catch (e: Exception) {
            deleteKey()
            throw e
        }
    }

    /** 確定沒有金鑰才回 null；Keystore 讀取失敗丟例外（Dart 端視為「暫時讀不到」）。 */
    private fun load(): Map<String, String>? {
        val store = keyStore()
        if (!store.containsAlias(ALIAS)) return null
        val publicKey = store.getCertificate(ALIAS).publicKey as ECPublicKey
        checkNotNull(store.getKey(ALIAS, null)) { "key missing" }
        return point(publicKey)
    }

    private fun sign(data: ByteArray): ByteArray {
        val key = keyStore().getKey(ALIAS, null) as? PrivateKey ?: error("no key")
        val der = Signature.getInstance("SHA256withECDSA").run {
            initSign(key)
            update(data)
            sign()
        }
        return ProofKeyCodec.rawSignature(der) ?: error("bad signature")
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val ALIAS = "tripline_dpop_key"
    }
}
