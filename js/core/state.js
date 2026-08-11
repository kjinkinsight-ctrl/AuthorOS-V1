/*
=========================================================
AUTHOROS
STATE ENGINE
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSState {

        constructor() {

            this.data = {

                app: {
                    version: "0.1.0",
                    initialized: false,
                    currentView: "dashboard"
                },

                projects: [],

                ideas: [],

                currentProject: null,

                settings: {
                    theme: "obsidian"
                },

                ui: {
                    sidebarCollapsed: false,
                    notifications: []
                }

            };

            this.listeners = new Map();
        }


        get(path = null) {

            if (!path) {
                return this.data;
            }

            return path
                .split(".")
                .reduce((object, key) => {
                    return object ? object[key] : undefined;
                }, this.data);
        }


        set(path, value) {

            const keys = path.split(".");
            const lastKey = keys.pop();

            let target = this.data;

            keys.forEach(key => {

                if (
                    typeof target[key] !== "object" ||
                    target[key] === null
                ) {
                    target[key] = {};
                }

                target = target[key];

            });

            target[lastKey] = value;

            this.notify(path, value);

            return value;
        }


        update(path, updates) {

            const current = this.get(path);

            if (
                typeof current !== "object" ||
                current === null
            ) {
                throw new Error(
                    `Cannot update non-object state path: ${path}`
                );
            }

            Object.assign(current, updates);

            this.notify(path, current);

            return current;
        }


        subscribe(path, callback) {

            if (typeof callback !== "function") {
                throw new TypeError(
                    "State subscription callback must be a function."
                );
            }

            if (!this.listeners.has(path)) {
                this.listeners.set(path, new Set());
            }

            this.listeners.get(path).add(callback);

            return () => {
                this.listeners.get(path)?.delete(callback);
            };
        }


        notify(path, value) {

            const listeners = this.listeners.get(path);

            if (!listeners) {
                return;
            }

            listeners.forEach(callback => {

                try {
                    callback(value, path);
                } catch (error) {
                    console.error(
                        "AuthorOS state listener error:",
                        error
                    );
                }

            });
        }


        reset() {

            this.data = {

                app: {
                    version: "0.1.0",
                    initialized: false,
                    currentView: "dashboard"
                },

                projects: [],

                ideas: [],

                currentProject: null,

                settings: {
                    theme: "system"
                },

                ui: {
                    sidebarCollapsed: false,
                    notifications: []
                }

            };

            this.listeners.clear();
        }

    }


    window.AuthorOSState = AuthorOSState;

})();