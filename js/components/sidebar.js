/*
=========================================================
AUTHOROS
SIDEBAR COMPONENT
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSSidebar {

        constructor(core) {
            this.core = core;
        }


        collapse() {

            const sidebar =
                document.getElementById(
                    "app-sidebar"
                );

            if (!sidebar) {
                return;
            }

            sidebar.classList.add(
                "collapsed"
            );

            this.core.state.set(
                "ui.sidebarCollapsed",
                true
            );

        }


        expand() {

            const sidebar =
                document.getElementById(
                    "app-sidebar"
                );

            if (!sidebar) {
                return;
            }

            sidebar.classList.remove(
                "collapsed"
            );

            this.core.state.set(
                "ui.sidebarCollapsed",
                false
            );

        }


        toggle() {

            const collapsed =
                this.core.state.get(
                    "ui.sidebarCollapsed"
                );

            collapsed
                ? this.expand()
                : this.collapse();

        }

    }


    window.AuthorOSSidebar =
        AuthorOSSidebar;

})();