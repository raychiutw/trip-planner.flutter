package com.raychiu.tripline

import java.io.ByteArrayOutputStream
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProofKeyCodecTest {
    private fun derInteger(bytes: ByteArray): ByteArray {
        val value = BigInteger(1, bytes).toByteArray() // 高位元為 1 時會補 0x00
        return byteArrayOf(0x02, value.size.toByte()) + value
    }

    private fun toDer(raw: ByteArray): ByteArray {
        val body = derInteger(raw.copyOfRange(0, 32)) + derInteger(raw.copyOfRange(32, 64))
        return ByteArrayOutputStream().apply {
            write(0x30)
            write(body.size)
            write(body)
        }.toByteArray()
    }

    @Test
    fun rawSignature_isValidEs256_forManyRandomKeys() {
        val generator = KeyPairGenerator.getInstance("EC").apply {
            initialize(ECGenParameterSpec("secp256r1"))
        }
        repeat(300) { i ->
            val pair = generator.generateKeyPair()
            val message = "message-$i".toByteArray()
            val der = Signature.getInstance("SHA256withECDSA").run {
                initSign(pair.private)
                update(message)
                sign()
            }

            val raw = ProofKeyCodec.rawSignature(der)!!

            assertEquals(64, raw.size)
            val verified = Signature.getInstance("SHA256withECDSA").run {
                initVerify(pair.public)
                update(message)
                verify(toDer(raw))
            }
            assertTrue("signature #$i must verify", verified)
        }
    }

    @Test
    fun rawSignature_padsShortIntegersAndStripsSignByte() {
        // r = 0x01、s = 0x80（DER 會補 0x00）
        val der = byteArrayOf(0x30, 0x07, 0x02, 0x01, 0x01, 0x02, 0x02, 0x00, 0x80.toByte())

        val raw = ProofKeyCodec.rawSignature(der)!!

        assertArrayEquals(ByteArray(31) + byteArrayOf(0x01), raw.copyOfRange(0, 32))
        assertArrayEquals(ByteArray(31) + byteArrayOf(0x80.toByte()), raw.copyOfRange(32, 64))
    }

    @Test
    fun rawSignature_rejectsMalformedInput() {
        assertNull(ProofKeyCodec.rawSignature(byteArrayOf()))
        assertNull(ProofKeyCodec.rawSignature(byteArrayOf(0x31, 0x00)))
        assertNull(ProofKeyCodec.rawSignature(byteArrayOf(0x30, 0x05, 0x02, 0x01)))
    }

    @Test
    fun coordinate_isAlways32BytesAndRoundTrips() {
        val generator = KeyPairGenerator.getInstance("EC").apply {
            initialize(ECGenParameterSpec("secp256r1"))
        }
        repeat(300) {
            val w = (generator.generateKeyPair().public as ECPublicKey).w
            for (v in listOf(w.affineX, w.affineY)) {
                val bytes = ProofKeyCodec.coordinate(v)
                assertEquals(32, bytes.size)
                assertEquals(v, BigInteger(1, bytes))
            }
        }
        assertEquals(32, ProofKeyCodec.coordinate(BigInteger.ONE).size)
    }
}
