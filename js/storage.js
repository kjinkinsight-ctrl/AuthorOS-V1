/*
=========================================================
AUTHOROS
STORAGE SERVICE
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSStorage {

        constructor() {

            this.prefix =
                "authoros";

            this.available =
                this.checkAvailability();

        }


        checkAvailability() {

            try {

                const testKey =
                    "__authoros_storage_test__";


                localStorage.setItem(
                    testKey,
                    "ok"
                );


                localStorage.removeItem(
                    testKey
                );


                return true;


            } catch (error) {

                console.error(
                    "AuthorOS storage unavailable:",
                    error
                );


                return false;

            }

        }


        makeKey(key) {

            return `${this.prefix}:${key}`;

        }


        get(
            key,
            fallback = null
        ) {

            if (!this.available) {
                return fallback;
            }


            try {

                const raw =
                    localStorage.getItem(
                        this.makeKey(key)
                    );


                if (
                    raw === null
                ) {

                    return fallback;

                }


                return JSON.parse(
                    raw
                );


            } catch (error) {

                console.error(
                    `AuthorOS storage read failed: ${key}`,
                    error
                );


                return fallback;

            }

        }


        set(
            key,
            value
        ) {

            if (!this.available) {
                return false;
            }


            try {

                localStorage.setItem(
                    this.makeKey(key),
                    JSON.stringify(value)
                );


                return true;


            } catch (error) {

                console.error(
                    `AuthorOS storage write failed: ${key}`,
                    error
                );


                return false;

            }

        }


        remove(key) {

            if (!this.available) {
                return false;
            }


            try {

                localStorage.removeItem(
                    this.makeKey(key)
                );


                return true;


            } catch (error) {

                console.error(
                    `AuthorOS storage delete failed: ${key}`,
                    error
                );


                return false;

            }

        }


        clear() {

            if (!this.available) {
                return false;
            }


            try {

                const prefix =
                    `${this.prefix}:`;


                const keys = [];


                for (
                    let index = 0;
                    index < localStorage.length;
                    index++
                ) {

                    const key =
                        localStorage.key(
                            index
                        );


                    if (
                        key &&
                        key.startsWith(prefix)
                    ) {

                        keys.push(key);

                    }

                }


                keys.forEach(
                    key => {

                        localStorage.removeItem(
                            key
                        );

                    }
                );


                return true;


            } catch (error) {

                console.error(
                    "AuthorOS storage clear failed:",
                    error
                );


                return false;

            }

        }


        /*
        =====================================================
        PROJECTS
        =====================================================
        */

        saveProjects(projects) {

            if (
                !Array.isArray(projects)
            ) {

                throw new TypeError(
                    "AuthorOS projects must be an array."
                );

            }


            return this.set(
                "projects",
                projects
            );

        }


        loadProjects() {

            const projects =
                this.get(
                    "projects",
                    []
                );


            return Array.isArray(
                projects
            )
                ? projects
                : [];

        }


        saveProject(project) {

            if (
                !AuthorOSProjectModel.validate(
                    project
                )
            ) {

                throw new Error(
                    "Cannot save invalid project."
                );

            }


            const projects =
                this.loadProjects();


            const existingIndex =
                projects.findIndex(
                    item =>
                        item.id ===
                        project.id
                );


            if (
                existingIndex === -1
            ) {

                projects.push(
                    project
                );

            } else {

                projects[
                    existingIndex
                ] = project;

            }


            return this.saveProjects(
                projects
            );

        }


        loadProject(projectId) {

            const projects =
                this.loadProjects();


            return (
                projects.find(
                    project =>
                        project.id ===
                        projectId
                ) || null
            );

        }


        deleteProject(projectId) {

            const projects =
                this.loadProjects();


            const filtered =
                projects.filter(
                    project =>
                        project.id !==
                        projectId
                );


            if (
                filtered.length ===
                projects.length
            ) {

                return false;

            }


            this.saveProjects(
                filtered
            );


            return true;

        }


        /*
        =====================================================
        BACKUPS
        =====================================================
        */

        saveBackups(backups) {

            if (
                !Array.isArray(backups)
            ) {

                throw new TypeError(
                    "AuthorOS backups must be an array."
                );

            }


            return this.set(
                "backups",
                backups
            );

        }


        loadBackups() {

            const backups =
                this.get(
                    "backups",
                    []
                );


            return Array.isArray(
                backups
            )
                ? backups
                : [];

        }


        saveBackup(backup) {

            if (
                !backup ||
                typeof backup !== "object"
            ) {

                throw new Error(
                    "Cannot save invalid backup payload."
                );

            }


            if (
                typeof backup.id !== "string" ||
                !backup.id.trim()
            ) {

                throw new Error(
                    "Backup id is required."
                );

            }


            if (
                typeof backup.projectId !== "string" ||
                !backup.projectId.trim()
            ) {

                throw new Error(
                    "Backup project id is required."
                );

            }


            const backups =
                this.loadBackups();


            const existingIndex =
                backups.findIndex(
                    item =>
                        item.id ===
                        backup.id
                );


            if (
                existingIndex === -1
            ) {

                backups.push(
                    backup
                );

            } else {

                backups[
                    existingIndex
                ] = backup;

            }


            return this.saveBackups(
                backups
            );

        }


        loadBackup(backupId) {

            if (
                typeof backupId !== "string" ||
                !backupId.trim()
            ) {

                return null;

            }


            return this.loadBackups()
                .find(
                    backup =>
                        backup.id ===
                        backupId.trim()
                ) || null;

        }


        loadProjectBackups(projectId) {

            if (
                typeof projectId !== "string" ||
                !projectId.trim()
            ) {

                return [];

            }


            return this.loadBackups()
                .filter(
                    backup =>
                        backup &&
                        backup.projectId ===
                        projectId.trim()
                );

        }


        deleteBackup(backupId) {

            if (
                typeof backupId !== "string" ||
                !backupId.trim()
            ) {

                return false;

            }


            const backups =
                this.loadBackups();


            const filtered =
                backups.filter(
                    backup =>
                        backup.id !==
                        backupId.trim()
                );


            if (
                filtered.length ===
                backups.length
            ) {

                return false;

            }


            return this.saveBackups(
                filtered
            );

        }


        /*
        =====================================================
        IDEAS
        =====================================================
        */

        saveIdeas(ideas) {

            if (
                !Array.isArray(ideas)
            ) {

                throw new TypeError(
                    "AuthorOS ideas must be an array."
                );

            }


            return this.set(
                "ideas",
                ideas
            );

        }


        loadIdeas() {

            const ideas =
                this.get(
                    "ideas",
                    []
                );


            return Array.isArray(
                ideas
            )
                ? ideas
                : [];

        }


        saveIdea(idea) {

            if (
                !idea ||
                typeof idea !== "object"
            ) {

                throw new Error(
                    "Cannot save invalid idea payload."
                );

            }


            if (
                typeof idea.id !== "string" ||
                !idea.id.trim()
            ) {

                throw new Error(
                    "Idea id is required."
                );

            }


            const ideas =
                this.loadIdeas();


            const existingIndex =
                ideas.findIndex(
                    item =>
                        item.id ===
                        idea.id
                );


            if (
                existingIndex === -1
            ) {

                ideas.push(
                    idea
                );

            } else {

                ideas[
                    existingIndex
                ] = idea;

            }


            return this.saveIdeas(
                ideas
            );

        }


        loadIdea(ideaId) {

            if (
                typeof ideaId !== "string" ||
                !ideaId.trim()
            ) {

                return null;

            }


            return this.loadIdeas()
                .find(
                    idea =>
                        idea.id ===
                        ideaId.trim()
                ) || null;

        }


        /*
        =====================================================
        SETTINGS
        =====================================================
        */

        saveSettings(settings) {

            return this.set(
                "settings",
                settings
            );

        }


        loadSettings() {

            return this.get(
                "settings",
                {
                    appearance: {
                        theme: "obsidian",
                        accent: "default",
                        accentColor: ""
                    }
                }
            );

        }


        /*
        =====================================================
        APPLICATION
        =====================================================
        */

        saveCurrentView(view) {

            return this.set(
                "currentView",
                view
            );

        }


        loadCurrentView() {

            return this.get(
                "currentView",
                "dashboard"
            );

        }


        saveActiveProjectId(projectId) {

            if (
                projectId === null ||
                projectId === undefined ||
                projectId === ""
            ) {

                return this.remove(
                    "activeProjectId"
                );

            }


            return this.set(
                "activeProjectId",
                String(projectId)
            );

        }


        loadActiveProjectId() {

            const projectId =
                this.get(
                    "activeProjectId",
                    null
                );


            return typeof projectId === "string" && projectId.trim()
                ? projectId.trim()
                : null;

        }

    }


    window.AuthorOSStorage =
        AuthorOSStorage;

})();