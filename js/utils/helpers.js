/*
=========================================================
AUTHOROS
HELPERS
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSHelpers = {

        generateId(prefix = "id") {

            return `${prefix}_${Date.now()}_${Math.random()
                .toString(36)
                .slice(2, 9)}`;

        },


        escapeHTML(value) {

            return String(value)
                .replaceAll("&", "&amp;")
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;")
                .replaceAll('"', "&quot;")
                .replaceAll("'", "&#039;");

        },


        isObject(value) {

            return (
                value !== null &&
                typeof value === "object" &&
                !Array.isArray(value)
            );

        }

    };

})();