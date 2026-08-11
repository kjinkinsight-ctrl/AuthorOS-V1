/*
=========================================================
AUTHOROS
PROJECT MODEL
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSProjectModel {

        static create(data = {}) {

            const now =
                new Date().toISOString();


            return {

                id:
                    data.id ||
                    AuthorOSHelpers.generateId(
                        "project"
                    ),

                name:
                    data.name ||
                    "Untitled Project",

                description:
                    data.description ||
                    "",

                type:
                    data.type ||
                    "novel",

                status:
                    data.status ||
                    "draft",

                genre:
                    data.genre ||
                    "",

                genreTags:
                    Array.isArray(
                        data.genreTags
                    )
                        ? data.genreTags
                            .map(
                                item => String(item || "").trim()
                            )
                            .filter(Boolean)
                        : String(data.genre || "").trim()
                            ? [String(data.genre).trim()]
                            : [],

                wordCount:
                    Number(
                        data.wordCount || 0
                    ),

                targetWordCount:
                    Number(
                        data.targetWordCount || 0
                    ),

                createdAt:
                    data.createdAt ||
                    now,

                updatedAt:
                    data.updatedAt ||
                    now,

                cover:
                    data.cover || null,

                manuscript: {

                    chapters:
                        Array.isArray(
                            data.manuscript?.chapters
                        )
                            ? data.manuscript.chapters
                            : [],

                    currentChapter:
                        data.manuscript
                            ?.currentChapter ||
                        null

                },

                story: {

                    characters:
                        Array.isArray(
                            data.story?.characters
                        )
                            ? data.story.characters
                            : [],

                    timeline:
                        Array.isArray(
                            data.story?.timeline
                        )
                            ? data.story.timeline
                            : [],

                    notes:
                        Array.isArray(
                            data.story?.notes
                        )
                            ? data.story.notes
                            : []

                }

            };

        }


        static validate(project) {

            if (
                !project ||
                typeof project !== "object"
            ) {
                return false;
            }


            if (
                !project.id ||
                typeof project.id !== "string"
            ) {
                return false;
            }


            if (
                !project.name ||
                typeof project.name !== "string"
            ) {
                return false;
            }


            return true;

        }


        static update(project, updates = {}) {

            if (
                !this.validate(project)
            ) {
                throw new Error(
                    "Invalid AuthorOS project."
                );
            }


            const updated = {
                ...project,
                ...updates
            };


            updated.updatedAt =
                new Date().toISOString();


            return updated;

        }

    }


    window.AuthorOSProjectModel =
        AuthorOSProjectModel;

})();