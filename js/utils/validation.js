/*
=========================================================
AUTHOROS
VALIDATION
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSValidation = {

        required(value) {

            return (
                value !== null &&
                value !== undefined &&
                String(value).trim().length > 0
            );

        },


        string(value) {

            return typeof value === "string";

        },


        object(value) {

            return (
                value !== null &&
                typeof value === "object" &&
                !Array.isArray(value)
            );

        },


        array(value) {

            return Array.isArray(value);

        }

    };

})();