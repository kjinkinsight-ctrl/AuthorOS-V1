/*
=========================================================
AUTHOROS
IMAGE ASSET UTILITIES
Local-first image validation and processing
=========================================================
*/

(function () {

    "use strict";

    const SUPPORTED_TYPES = new Set([
        "image/jpeg",
        "image/png",
        "image/webp"
    ]);

    const EXTENSION_TO_MIME = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp"
    };

    const DEFAULTS = {
        maxFileBytes: 6 * 1024 * 1024,
        maxWidth: 1280,
        maxHeight: 1280,
        outputType: "image/webp",
        quality: 0.86
    };

    const ImageAssets = {

        getSupportedMimeTypes() {
            return Array.from(SUPPORTED_TYPES);
        },


        getSupportedExtensions() {
            return Object.keys(EXTENSION_TO_MIME);
        },


        isSupportedFile(file) {

            if (!file || typeof file !== "object") {
                return false;
            }

            const mime = String(file.type || "").toLowerCase();

            if (SUPPORTED_TYPES.has(mime)) {
                return true;
            }

            const name = String(file.name || "").toLowerCase();

            return Object.keys(EXTENSION_TO_MIME)
                .some(extension => name.endsWith(extension));

        },


        validateFile(file, options = {}) {

            const maxFileBytes =
                Number.isFinite(Number(options.maxFileBytes))
                    ? Number(options.maxFileBytes)
                    : DEFAULTS.maxFileBytes;

            if (!file) {
                return {
                    ok: false,
                    error: "No image file was selected."
                };
            }

            if (!this.isSupportedFile(file)) {
                return {
                    ok: false,
                    error: "Unsupported image format. Please use JPG, PNG, or WEBP."
                };
            }

            if (!Number.isFinite(Number(file.size)) || Number(file.size) <= 0) {
                return {
                    ok: false,
                    error: "The selected image is invalid."
                };
            }

            if (Number(file.size) > maxFileBytes) {
                return {
                    ok: false,
                    error: `Image is too large. Maximum supported size is ${this.formatBytes(maxFileBytes)}.`
                };
            }

            return { ok: true };

        },


        async processFile(file, options = {}) {

            const validation = this.validateFile(file, options);

            if (!validation.ok) {
                return validation;
            }

            const config = {
                ...DEFAULTS,
                ...(options || {})
            };

            try {
                const image = await this.loadImageFromFile(file);
                const dimensions = this.getScaledDimensions(
                    image.naturalWidth,
                    image.naturalHeight,
                    Number(config.maxWidth),
                    Number(config.maxHeight)
                );

                const canvas = document.createElement("canvas");
                canvas.width = dimensions.width;
                canvas.height = dimensions.height;

                const context = canvas.getContext("2d", {
                    alpha: true,
                    desynchronized: true
                });

                if (!context) {
                    return {
                        ok: false,
                        error: "Unable to process this image in your browser."
                    };
                }

                context.imageSmoothingEnabled = true;
                context.imageSmoothingQuality = "high";
                context.drawImage(image, 0, 0, dimensions.width, dimensions.height);

                const outputType = this.resolveOutputType(file, config.outputType);
                const quality = Number.isFinite(Number(config.quality))
                    ? Math.max(0.4, Math.min(0.96, Number(config.quality)))
                    : DEFAULTS.quality;

                const dataUrl = canvas.toDataURL(outputType, quality);
                const sizeBytes = this.estimateDataUrlBytes(dataUrl);

                return {
                    ok: true,
                    asset: {
                        dataUrl,
                        mimeType: outputType,
                        width: dimensions.width,
                        height: dimensions.height,
                        sizeBytes,
                        sourceName: String(file.name || ""),
                        updatedAt: new Date().toISOString()
                    }
                };

            } catch (error) {
                return {
                    ok: false,
                    error: "Unable to use this image. Please choose a valid JPG, PNG, or WEBP image within the supported size."
                };
            }

        },


        normalizeStoredAsset(value, limits = {}) {

            if (!value || typeof value !== "object") {
                return null;
            }

            const dataUrl = String(value.dataUrl || "").trim();

            if (!this.isValidDataImageUrl(dataUrl)) {
                return null;
            }

            const maxStoredBytes = Number.isFinite(Number(limits.maxStoredBytes))
                ? Number(limits.maxStoredBytes)
                : 2 * 1024 * 1024;

            const sizeBytes = Number.isFinite(Number(value.sizeBytes))
                ? Number(value.sizeBytes)
                : this.estimateDataUrlBytes(dataUrl);

            if (sizeBytes > maxStoredBytes) {
                return null;
            }

            return {
                dataUrl,
                mimeType: String(value.mimeType || "image/webp"),
                width: Math.max(1, Math.trunc(Number(value.width || 1))),
                height: Math.max(1, Math.trunc(Number(value.height || 1))),
                sizeBytes,
                sourceName: String(value.sourceName || ""),
                updatedAt: String(value.updatedAt || "")
            };

        },


        resolveOutputType(file, preferredType) {

            const preferred = String(preferredType || "").toLowerCase();

            if (SUPPORTED_TYPES.has(preferred)) {
                return preferred;
            }

            const inputType = String(file?.type || "").toLowerCase();

            if (inputType === "image/png") {
                return "image/png";
            }

            if (inputType === "image/webp") {
                return "image/webp";
            }

            return "image/jpeg";

        },


        getScaledDimensions(width, height, maxWidth, maxHeight) {

            const safeWidth = Math.max(1, Math.trunc(Number(width) || 1));
            const safeHeight = Math.max(1, Math.trunc(Number(height) || 1));
            const limitWidth = Math.max(32, Math.trunc(Number(maxWidth) || DEFAULTS.maxWidth));
            const limitHeight = Math.max(32, Math.trunc(Number(maxHeight) || DEFAULTS.maxHeight));

            const ratio = Math.min(
                1,
                limitWidth / safeWidth,
                limitHeight / safeHeight
            );

            return {
                width: Math.max(1, Math.round(safeWidth * ratio)),
                height: Math.max(1, Math.round(safeHeight * ratio))
            };

        },


        loadImageFromFile(file) {

            return new Promise((resolve, reject) => {
                const reader = new FileReader();

                reader.onerror = () => {
                    reject(new Error("read-failed"));
                };

                reader.onload = () => {
                    const image = new Image();

                    image.onerror = () => reject(new Error("decode-failed"));
                    image.onload = () => resolve(image);
                    image.src = String(reader.result || "");
                };

                reader.readAsDataURL(file);
            });

        },


        estimateDataUrlBytes(dataUrl) {

            const value = String(dataUrl || "");
            const commaIndex = value.indexOf(",");

            if (commaIndex === -1) {
                return 0;
            }

            const base64 = value.slice(commaIndex + 1).replace(/\s+/g, "");
            const padding = base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0;

            return Math.max(0, Math.floor((base64.length * 3) / 4) - padding);

        },


        isValidDataImageUrl(value) {

            const input = String(value || "").trim();

            if (!input.startsWith("data:image/")) {
                return false;
            }

            if (!input.includes(";base64,")) {
                return false;
            }

            return /^data:image\/(jpeg|jpg|png|webp);base64,[a-zA-Z0-9+/=\s]+$/.test(input);

        },


        formatBytes(bytes) {

            const value = Number(bytes || 0);

            if (!Number.isFinite(value) || value <= 0) {
                return "0 B";
            }

            if (value < 1024) {
                return `${value} B`;
            }

            if (value < 1024 * 1024) {
                return `${(value / 1024).toFixed(1)} KB`;
            }

            return `${(value / (1024 * 1024)).toFixed(1)} MB`;

        }

    };


    window.AuthorOSImageAssets = ImageAssets;

})();
