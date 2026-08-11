/*
=========================================================
AUTHOROS
MODAL COMPONENT
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSModal {

        constructor() {

            this.container =
                document.getElementById(
                    "modal-container"
                );

            this.previousFocus = null;

            this.boundHandleEscape =
                event => {

                    if (event.key === "Escape") {
                        event.preventDefault();
                        this.close();
                    }

                };

        }


        open(options = {}) {

            if (!this.container) {
                return;
            }

            const title =
                options.title || "Author Studio";

            const content =
                options.content || "";

            this.previousFocus =
                document.activeElement instanceof HTMLElement
                    ? document.activeElement
                    : null;

            this.container.innerHTML = `

                <div class="modal-backdrop"></div>

                <div
                    class="modal"
                    role="dialog"
                    aria-modal="true"
                    aria-label="${this.escape(title)}"
                >

                    <div class="modal-header">
                        <h2>${this.escape(title)}</h2>
                    </div>

                    <div class="modal-body">
                        ${content}
                    </div>

                    <div class="modal-footer">

                        <button
                            type="button"
                            class="modal-cancel"
                        >
                            ${this.escape(
                                options.cancelText ||
                                "Cancel"
                            )}
                        </button>

                        <button
                            type="button"
                            class="modal-confirm"
                        >
                            ${this.escape(
                                options.confirmText ||
                                "Confirm"
                            )}
                        </button>

                    </div>

                </div>
            `;

            this.container.classList.add(
                "active"
            );

            const backdrop =
                this.container.querySelector(
                    ".modal-backdrop"
                );

            backdrop?.addEventListener(
                "click",
                () => this.close()
            );

            this.container
                .querySelector(".modal-cancel")
                ?.addEventListener(
                    "click",
                    () => {

                        if (
                            typeof options.onCancel ===
                            "function"
                        ) {
                            options.onCancel();
                        }

                        this.close();

                    }
                );

            this.container
                .querySelector(".modal-confirm")
                ?.addEventListener(
                    "click",
                    () => {

                        if (
                            typeof options.onConfirm ===
                            "function"
                        ) {
                            options.onConfirm();
                        }

                        this.close();

                    }
                );

            document.addEventListener(
                "keydown",
                this.boundHandleEscape
            );

            const initialFocus =
                this.container.querySelector(".modal-cancel") ||
                this.container.querySelector(".modal-confirm");

            if (initialFocus instanceof HTMLElement) {
                initialFocus.focus();
            }

        }


        close() {

            if (!this.container) {
                return;
            }

            this.container.classList.remove(
                "active"
            );

            this.container.innerHTML = "";

            document.removeEventListener(
                "keydown",
                this.boundHandleEscape
            );

            if (this.previousFocus instanceof HTMLElement) {
                this.previousFocus.focus();
            }

            this.previousFocus = null;

        }


        escape(value) {

            return String(value)
                .replaceAll("&", "&amp;")
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;")
                .replaceAll('"', "&quot;")
                .replaceAll("'", "&#039;");

        }

    }


    window.AuthorOSModal =
        AuthorOSModal;

})();