/*
=========================================================
AUTHOROS
DESKTOP RUNTIME ADAPTER
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSDesktop = {

        isTauri() {
            return Boolean(
                window.__TAURI__ &&
                window.__TAURI__.dialog &&
                window.__TAURI__.fs
            );
        },


        async saveTextFile(options = {}) {

            if (!this.isTauri()) {
                return {
                    ok: false,
                    unsupported: true,
                    error: "Desktop file save is unavailable in this runtime."
                };
            }

            try {

                const dialog = window.__TAURI__.dialog;
                const fs = window.__TAURI__.fs;
                const fileName = String(options.fileName || "Author-Studio-Export.txt");
                const content = String(options.text || "");
                const path = await dialog.save({
                    defaultPath: fileName,
                    filters: this.buildSaveFilters(fileName, options.mimeType)
                });

                if (!path) {
                    return {
                        ok: false,
                        canceled: true,
                        error: "Save canceled."
                    };
                }

                await fs.writeTextFile(path, content);

                return {
                    ok: true,
                    path,
                    bytes: new TextEncoder().encode(content).byteLength
                };

            } catch (error) {

                console.error("AuthorOS desktop save failed:", error);

                return {
                    ok: false,
                    error: error instanceof Error
                        ? error.message
                        : "Desktop file save failed."
                };

            }

        },


        async openFile(options = {}) {

            if (!this.isTauri()) {
                return {
                    ok: false,
                    unsupported: true,
                    error: "Desktop file open is unavailable in this runtime."
                };
            }

            try {

                const dialog = window.__TAURI__.dialog;
                const fs = window.__TAURI__.fs;
                const path = await dialog.open({
                    multiple: false,
                    directory: false,
                    filters: this.buildOpenFilters(options.filters)
                });

                if (!path || Array.isArray(path)) {
                    return {
                        ok: false,
                        canceled: true,
                        error: "Open canceled."
                    };
                }

                const bytes = await fs.readFile(path);
                const fileName = this.getBaseName(path);
                const type = this.inferMimeType(fileName, options.mimeType);

                return {
                    ok: true,
                    path,
                    file: this.createFileLike(bytes, fileName, type)
                };

            } catch (error) {

                console.error("AuthorOS desktop open failed:", error);

                return {
                    ok: false,
                    error: error instanceof Error
                        ? error.message
                        : "Desktop file open failed."
                };

            }

        },


        buildSaveFilters(fileName, mimeType) {

            const extension = this.getFileExtension(fileName);

            if (!extension) {
                return [];
            }

            const normalizedExtension = extension.replace(/^\./, "").toLowerCase();
            const label = mimeType && String(mimeType).includes("json")
                ? "JSON"
                : normalizedExtension.toUpperCase();

            return [
                {
                    name: `${label} files`,
                    extensions: [normalizedExtension]
                }
            ];

        },


        buildOpenFilters(filters) {

            if (!Array.isArray(filters)) {
                return [];
            }

            return filters
                .filter(filter => filter && typeof filter === "object")
                .map(filter => ({
                    name: String(filter.name || "Files"),
                    extensions: Array.isArray(filter.extensions)
                        ? filter.extensions.map(extension => String(extension || "").replace(/^\./, "").toLowerCase()).filter(Boolean)
                        : []
                }))
                .filter(filter => filter.extensions.length);

        },


        createFileLike(bytes, fileName, mimeType) {

            const data = bytes instanceof Uint8Array
                ? bytes
                : new Uint8Array(bytes || []);

            if (typeof File === "function") {
                return new File([data], fileName, {
                    type: mimeType || "application/octet-stream"
                });
            }

            const blob = new Blob([data], {
                type: mimeType || "application/octet-stream"
            });

            blob.name = fileName;
            blob.lastModified = Date.now();

            return blob;

        },


        getBaseName(path) {

            const normalized = String(path || "").replace(/\\/g, "/");
            const parts = normalized.split("/").filter(Boolean);
            return parts.length
                ? parts[parts.length - 1]
                : "selected-file";

        },


        inferMimeType(fileName, fallbackMimeType) {

            const extension = this.getFileExtension(fileName).toLowerCase();

            if (extension === ".json") {
                return "application/json";
            }

            if (extension === ".txt") {
                return "text/plain";
            }

            if (extension === ".md" || extension === ".markdown") {
                return "text/markdown";
            }

            if (extension === ".html" || extension === ".htm") {
                return "text/html";
            }

            if (extension === ".doc") {
                return "application/msword";
            }

            return String(fallbackMimeType || "application/octet-stream");

        },


        getFileExtension(fileName) {

            const value = String(fileName || "").trim();
            const index = value.lastIndexOf(".");

            if (index === -1 || index === value.length - 1) {
                return "";
            }

            return value.slice(index);

        }

    };

})();
