/*
=========================================================
AUTHOROS
DIAGNOSTICS
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSDiagnostics {

        constructor(core) {

            this.core = core;

        }


        run() {

            const results = [];


            results.push(
                this.checkCore()
            );


            results.push(
                this.checkState()
            );


            results.push(
                this.checkStorage()
            );


            results.push(
                this.checkNavigation()
            );


            results.push(
                this.checkRegistry()
            );


            results.push(
                this.checkDOM()
            );


            return {

                passed:
                    results.every(
                        result =>
                            result.status ===
                            "passed"
                    ),

                checks:
                    results,

                timestamp:
                    new Date().toISOString()

            };

        }


        checkCore() {

            return {

                name:
                    "Core",

                status:
                    this.core &&
                    this.core.initialized
                        ? "passed"
                        : "failed"

            };

        }


        checkState() {

            const state =
                this.core.state;


            return {

                name:
                    "State",

                status:
                    state &&
                    typeof state.get ===
                    "function"
                        ? "passed"
                        : "failed"

            };

        }


        checkStorage() {

            return {

                name:
                    "Storage",

                status:
                    this.core.storage &&
                    this.core.storage.available
                        ? "passed"
                        : "warning"

            };

        }


        checkNavigation() {

            return {

                name:
                    "Navigation",

                status:
                    this.core.navigation &&
                    this.core.navigation.routes.size > 0
                        ? "passed"
                        : "failed"

            };

        }


        checkRegistry() {

            return {

                name:
                    "Module Registry",

                status:
                    this.core.registry &&
                    this.core.registry.modules.size > 0
                        ? "passed"
                        : "failed"

            };

        }


        checkDOM() {

            const requiredElements = [

                "authoros-app",

                "app-toolbar",

                "app-sidebar",

                "app-content",

                "view-container",

                "app-statusbar"

            ];


            const missing =
                requiredElements.filter(
                    id =>
                        !document.getElementById(
                            id
                        )
                );


            return {

                name:
                    "Application DOM",

                status:
                    missing.length === 0
                        ? "passed"
                        : "failed",

                missing

            };

        }

    }


    window.AuthorOSDiagnostics =
        AuthorOSDiagnostics;

})();