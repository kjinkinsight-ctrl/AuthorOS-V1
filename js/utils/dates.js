/*
=========================================================
AUTHOROS
DATE UTILITIES
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSDates = {

        now() {
            return new Date();
        },


        timestamp() {
            return Date.now();
        },


        iso() {
            return new Date().toISOString();
        },


        format(date) {

            const value =
                date instanceof Date
                    ? date
                    : new Date(date);

            return value.toLocaleDateString(
                undefined,
                {
                    year: "numeric",
                    month: "short",
                    day: "numeric"
                }
            );

        }

    };

})();