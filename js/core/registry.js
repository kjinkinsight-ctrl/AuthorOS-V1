/*
=========================================================
AUTHOROS
MODULE REGISTRY
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSRegistry {

        constructor() {

            this.modules = new Map();

        }


        register(name, module) {

            if (!name) {
                throw new Error(
                    "Module registration requires a name."
                );
            }

            if (!module) {
                throw new Error(
                    `Module "${name}" is empty.`
                );
            }

            if (this.modules.has(name)) {
                console.warn(
                    `AuthorOS module "${name}" is already registered.`
                );

                return false;
            }

            this.modules.set(name, module);

            return true;
        }


        get(name) {
            return this.modules.get(name);
        }


        has(name) {
            return this.modules.has(name);
        }


        all() {
            return Array.from(this.modules.values());
        }


        names() {
            return Array.from(this.modules.keys());
        }


        initializeAll(context) {

            this.modules.forEach((module, name) => {

                if (
                    typeof module.initialize !== "function"
                ) {
                    return;
                }

                try {

                    module.initialize(context);

                } catch (error) {

                    console.error(
                        `Failed to initialize module "${name}":`,
                        error
                    );

                }

            });

        }

    }


    window.AuthorOSRegistry = AuthorOSRegistry;

})();