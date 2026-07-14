# Tripline App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter placeholder launcher icon with the approved Tripline wood-brown compass-pin design on iOS and Android.

**Architecture:** Generate one approved monochrome mark, composite it onto exact RGB brand colors, and reuse the same geometry for every appearance. Bind three 1024 px images through the native iOS Single Size asset catalog and resize the default image into the existing Android density folders.

**Tech Stack:** Image generation, native macOS CoreGraphics/ImageIO, Xcode asset catalogs, Android mipmaps, Flutter.

## Global Constraints

- Default colors: `#A97A4A` and `#FFFBF5`.
- Dark colors: `#1A140F` and `#A97A4A`.
- Tinted colors: `#818181` and `#FFFFFF`.
- Keep identical geometry across all appearances and let the OS apply corner masks.
- Add no package or runtime code.

---

### Task 1: Produce the three master icons

**Files:**
- Create: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- Create: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024-dark@1x.png`
- Create: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024-tinted@1x.png`

**Interfaces:**
- Consumes: approved compass-pin geometry and exact palette above.
- Produces: three opaque RGB 1024×1024 PNG files with matching geometry.

- [x] **Step 1: Generate the approved monochrome compass-pin mark**

Use image generation with this exact prompt:

```text
A single centered app icon glyph only: a rounded map-location pin outline containing a bold navigation compass arrow, matching the approved balanced-line concept. Flat geometric vector style, symmetric and highly legible at 20 px. Solid white glyph on a fully transparent square background. No text, letters, border, rounded-square background, gradient, lighting, texture, shadow, glow, perspective, or extra objects. 1024 by 1024.
```

- [x] **Step 2: Composite the shared mark over exact colors**

Use a temporary native CoreGraphics/ImageIO helper outside the repository to read the mark as an alpha mask and emit opaque RGB PNGs. Apply these exact pairs without changing the mask: `A97A4A/FFFBF5`, `1A140F/A97A4A`, and `818181/FFFFFF`.

- [x] **Step 3: Verify masters**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024*.png
```

Expected: every file reports `1024`, `1024`, and `hasAlpha: no`.

### Task 2: Bind native launcher assets

**Files:**
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Delete: legacy `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*` size variants other than the three masters.
- Modify: `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`

**Interfaces:**
- Consumes: Task 1 master PNGs.
- Produces: native iOS Default/Dark/Tinted selection and Android default launcher images.

- [x] **Step 1: Replace the iOS catalog manifest**

Use:

```json
{
  "images" : [
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [{ "appearance" : "luminosity", "value" : "dark" }],
      "filename" : "Icon-App-1024x1024-dark@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [{ "appearance" : "luminosity", "value" : "tinted" }],
      "filename" : "Icon-App-1024x1024-tinted@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [x] **Step 2: Resize the default master for Android**

Run `sips -z` for mdpi `48`, hdpi `72`, xhdpi `96`, xxhdpi `144`, and xxxhdpi `192`, writing to each existing `ic_launcher.png`.

- [x] **Step 3: Verify native files**

Run `jq empty` on `Contents.json`, inspect every PNG with `sips`, and run `git diff --check`.

Expected: valid JSON, correct dimensions, opaque PNGs, and no whitespace errors.

### Task 3: Build verification

**Files:**
- No source changes.

**Interfaces:**
- Consumes: bound native assets from Task 2.
- Produces: build evidence that both platforms accept the icon assets.

- [x] **Step 1: Verify iOS asset compilation**

Run:

```bash
flutter build ios --simulator --no-codesign
```

Expected: exit code `0` with the Runner simulator app built.

- [x] **Step 2: Verify Android resource compilation**

Run:

```bash
flutter build apk --debug
```

Expected: exit code `0` and `build/app/outputs/flutter-apk/app-debug.apk`.

- [x] **Step 3: Review the final diff**

Run:

```bash
git status --short
git diff --stat
git diff --check
```

Expected: only the design spec, implementation plan, icon catalog, and launcher images are changed; no generated build output is tracked.
