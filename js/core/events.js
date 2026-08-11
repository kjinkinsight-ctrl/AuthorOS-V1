/*
=========================================================
AUTHOROS
EVENT BUS
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSEventBus {

        constructor() {
            this.events = new Map();
        }


        on(eventName, callback) {

            if (typeof callback !== "function") {
                throw new TypeError(
                    "Event callback must be a function."
                );
            }

            if (!this.events.has(eventName)) {
                this.events.set(eventName, new Set());
            }

            this.events.get(eventName).add(callback);

            return () => {
                this.off(eventName, callback);
            };
        }


        off(eventName, callback) {

            const listeners = this.events.get(eventName);

            if (!listeners) {
                return;
            }

            listeners.delete(callback);

            if (listeners.size === 0) {
                this.events.delete(eventName);
            }
        }


        emit(eventName, payload = null) {

            const listeners = this.events.get(eventName);

            if (!listeners) {
                return;
            }

            listeners.forEach(callback => {

                try {
                    callback(payload);
                } catch (error) {

                    console.error(
                        `AuthorOS event error [${eventName}]:`,
                        error
                    );

                }

            });
        }


        clear() {
            this.events.clear();
        }

    }


    window.AuthorOSEventBus = AuthorOSEventBus;

})();