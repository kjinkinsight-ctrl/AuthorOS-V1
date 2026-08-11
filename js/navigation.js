/*
=========================================================
AUTHOROS
NAVIGATION
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSNavigation {

        constructor(core) {

            this.core =
                core;

            this.routes =
                new Map();

            this.currentRoute =
                null;

        }


        register(
            route,
            config
        ) {

            if (!route) {

                throw new Error(
                    "Navigation route requires a name."
                );

            }


            if (
                typeof config !==
                "object" ||
                config === null
            ) {

                throw new TypeError(
                    `Invalid navigation configuration for "${route}".`
                );

            }


            this.routes.set(
                route,
                {

                    title:
                        config.title ||
                        route,

                    render:
                        config.render ||
                        null

                }
            );

        }


        has(route) {

            return this.routes.has(
                route
            );

        }


        get(route) {

            return this.routes.get(
                route
            );

        }


        all() {

            return Array.from(
                this.routes.entries()
            );

        }


        navigate(route) {

            const config =
                this.routes.get(
                    route
                );


            if (!config) {

                console.warn(
                    `AuthorOS route not found: ${route}`
                );

                this.core.notify(
                    `Workspace "${route}" is unavailable.`,
                    "error"
                );

                return false;

            }


            try {

                const leavingWorkspace =
                    this.currentRoute ===
                    "project-workspace" &&
                    route !==
                    "project-workspace";


                if (
                    leavingWorkspace &&
                    this.core.autosave?.dirty
                ) {

                    this.core.autosave.flush({
                        reason:
                            "route-change"
                    });

                }

                this.currentRoute =
                    route;


                this.core.state.set(
                    "app.currentView",
                    route
                );


                this.core.storage.saveCurrentView(
                    route
                );


                this.render(
                    config
                );


                this.updateNavigationUI(
                    route
                );


                this.core.events.emit(
                    "navigation:changed",
                    {

                        route,

                        title:
                            config.title

                    }
                );


                return true;


            } catch (error) {

                console.error(
                    `Navigation failed: ${route}`,
                    error
                );


                this.core.notify(
                    "Unable to open this workspace.",
                    "error"
                );


                return false;

            }

        }


        render(config) {

            const container =
                document.getElementById(
                    "view-container"
                );


            if (!container) {

                throw new Error(
                    "View container not found."
                );

            }


            container.scrollTop = 0;


            if (
                typeof config.render ===
                "function"
            ) {

                config.render(
                    container
                );

                return;

            }


            container.innerHTML = `

                <section
                    class="empty-view"
                >

                    <div
                        class="empty-view-icon"
                    >
                        ◇
                    </div>

                    <h1>
                        ${this.escapeHTML(
                            config.title
                        )}
                    </h1>

                    <p>
                        This Author Studio workspace is ready for development.
                    </p>

                </section>

            `;

        }


        updateNavigationUI(route) {

            document
                .querySelectorAll(
                    "[data-route]"
                )
                .forEach(
                    item => {

                        item.classList.toggle(
                            "active",
                            item.dataset.route ===
                            route
                        );

                    }
                );


            const title =
                document.getElementById(
                    "current-view-title"
                );


            const config =
                this.routes.get(
                    route
                );


            if (
                title &&
                config
            ) {

                title.textContent =
                    config.title;

            }

        }


        start(
            route = "dashboard"
        ) {

            if (
                !this.has(route)
            ) {

                route =
                    "dashboard";

            }


            return this.navigate(
                route
            );

        }


        escapeHTML(value) {

            return String(value)

                .replaceAll(
                    "&",
                    "&amp;"
                )

                .replaceAll(
                    "<",
                    "&lt;"
                )

                .replaceAll(
                    ">",
                    "&gt;"
                )

                .replaceAll(
                    '"',
                    "&quot;"
                )

                .replaceAll(
                    "'",
                    "&#039;"
                );

        }

    }


    window.AuthorOSNavigation =
        AuthorOSNavigation;

})();