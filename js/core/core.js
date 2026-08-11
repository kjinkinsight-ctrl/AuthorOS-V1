/*
=========================================================
AUTHOROS
CORE APPLICATION
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSCore {

        constructor() {

            this.version =
                "1.0.0";


            this.state =
                new AuthorOSState();


            this.events =
                new AuthorOSEventBus();


            this.registry =
                new AuthorOSRegistry();


            this.storage =
                null;


            this.navigation =
                null;


            this.projectService =
                null;


            this.autosave =
                null;


            this.diagnostics =
                null;


            this.initialized =
                false;

        }


        /*
        =====================================================
        INITIALIZE
        =====================================================
        */

        initialize() {

            if (
                this.initialized
            ) {

                return this;

            }


            try {

                this.projectService =
                    new AuthorOSProjectService(
                        this
                    );


                this.autosave =
                    new AuthorOSAutosave(
                        this
                    );


                this.diagnostics =
                    new AuthorOSDiagnostics(
                        this
                    );


                this.state.set(
                    "app.version",
                    this.version
                );


                this.state.set(
                    "app.initialized",
                    true
                );


                this.initialized =
                    true;


                this.autosave.initialize();


                this.events.emit(
                    "app:initialized",
                    this
                );


                return this;


            } catch (error) {

                console.error(
                    "AuthorOS initialization failed:",
                    error
                );


                throw error;

            }

        }


        /*
        =====================================================
        NOTIFICATIONS
        =====================================================
        */

        notify(
            message,
            type = "info"
        ) {

            this.events.emit(
                "notification",
                {

                    message,

                    type,

                    timestamp:
                        Date.now()

                }
            );

        }


        /*
        =====================================================
        STATUS
        =====================================================
        */

        setStatus(message) {

            const element =
                document.getElementById(
                    "status-message"
                );


            if (
                element
            ) {

                element.textContent =
                    message;

            }

        }


        /*
        =====================================================
        STATE
        =====================================================
        */

        getState() {

            return this.state.get();

        }


        /*
        =====================================================
        VERSION
        =====================================================
        */

        getVersion() {

            return this.version;

        }


        /*
        =====================================================
        DIAGNOSTICS
        =====================================================
        */

        diagnose() {

            if (
                !this.diagnostics
            ) {

                return null;

            }


            return this.diagnostics.run();

        }


        /*
        =====================================================
        SHUTDOWN
        =====================================================
        */

        shutdown() {

            try {

                if (
                    this.autosave
                ) {

                    this.autosave.flush({
                        reason:
                            "shutdown"
                    });

                    this.autosave.stop();

                }


                if (
                    this.storage
                ) {

                    this.storage.saveProjects(
                        this.state.get(
                            "projects"
                        )
                    );


                    this.storage.saveSettings(
                        this.state.get(
                            "settings"
                        )
                    );


                    this.storage.saveCurrentView(
                        this.state.get(
                            "app.currentView"
                        )
                    );

                }


                this.events.emit(
                    "app:shutdown"
                );


                return true;


            } catch (error) {

                console.error(
                    "AuthorOS shutdown error:",
                    error
                );


                return false;

            }

        }

    }


    window.AuthorOSCore =
        AuthorOSCore;

})();