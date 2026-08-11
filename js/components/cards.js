/*
=========================================================
AUTHOROS
CARD COMPONENTS
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    const AuthorOSCards = {

        create(options = {}) {

            const card =
                document.createElement("article");

            card.className =
                options.className ||
                "card";

            if (options.title) {

                const header =
                    document.createElement("div");

                header.className =
                    "card-header";

                header.textContent =
                    options.title;

                card.appendChild(header);

            }

            if (options.content) {

                const body =
                    document.createElement("div");

                body.className =
                    "card-body";

                if (
                    typeof options.content ===
                    "string"
                ) {
                    body.innerHTML =
                        options.content;
                } else {
                    body.appendChild(
                        options.content
                    );
                }

                card.appendChild(body);

            }

            return card;

        }

    };


    window.AuthorOSCards =
        AuthorOSCards;

})();