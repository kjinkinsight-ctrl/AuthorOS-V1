/*
=========================================================
AUTHOROS
PROJECT SERVICE
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSProjectService {

        constructor(core) {

            this.core = core;

        }


        /*
        =====================================================
        CREATE PROJECT
        =====================================================
        */

        create(data = {}) {

            const project =
                AuthorOSProjectModel.create(
                    data
                );


            if (
                !AuthorOSProjectModel.validate(
                    project
                )
            ) {

                throw new Error(
                    "Unable to create a valid AuthorOS project."
                );

            }


            const projects =
                this.core.state.get(
                    "projects"
                );


            projects.push(
                project
            );


            this.core.state.set(
                "projects",
                projects
            );


            this.core.storage.saveProjects(
                projects
            );


            this.core.state.set(
                "currentProject",
                project
            );


            this.core.events.emit(
                "project:created",
                project
            );


            this.core.notify(
                `Project "${project.name}" created.`,
                "success"
            );


            return project;

        }


        /*
        =====================================================
        GET ALL PROJECTS
        =====================================================
        */

        getAll() {

            const projects =
                this.core.state.get(
                    "projects"
                );


            return Array.isArray(
                projects
            )
                ? projects
                : [];

        }


        /*
        =====================================================
        GET PROJECT
        =====================================================
        */

        getById(projectId) {

            return this.getAll().find(
                project =>
                    project.id ===
                    projectId
            ) || null;

        }


        /*
        =====================================================
        OPEN PROJECT
        =====================================================
        */

        open(projectId) {

            const project =
                this.getById(
                    projectId
                );


            if (!project) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return null;

            }


            this.core.state.set(
                "currentProject",
                project
            );


            this.core.events.emit(
                "project:opened",
                project
            );


            this.core.notify(
                `Project "${project.name}" opened.`,
                "success"
            );


            return project;

        }


        /*
        =====================================================
        UPDATE PROJECT
        =====================================================
        */

        update(
            projectId,
            updates = {}
        ) {

            const existing =
                this.getById(
                    projectId
                );


            if (!existing) {

                throw new Error(
                    "Cannot update a project that does not exist."
                );

            }


            const updated =
                AuthorOSProjectModel.update(
                    existing,
                    updates
                );


            const projects =
                this.getAll();


            const index =
                projects.findIndex(
                    project =>
                        project.id ===
                        projectId
                );


            projects[index] =
                updated;


            this.core.state.set(
                "projects",
                projects
            );


            this.core.storage.saveProjects(
                projects
            );


            const currentProject =
                this.core.state.get(
                    "currentProject"
                );


            if (
                currentProject &&
                currentProject.id ===
                projectId
            ) {

                this.core.state.set(
                    "currentProject",
                    updated
                );

            }


            this.core.events.emit(
                "project:updated",
                updated
            );


            return updated;

        }


        /*
        =====================================================
        DELETE PROJECT
        =====================================================
        */

        delete(projectId) {

            const existing =
                this.getById(
                    projectId
                );


            if (!existing) {

                return false;

            }


            const deleted =
                this.core.storage.deleteProject(
                    projectId
                );


            if (!deleted) {

                return false;

            }


            const projects =
                this.core.storage.loadProjects();


            this.core.state.set(
                "projects",
                projects
            );


            const currentProject =
                this.core.state.get(
                    "currentProject"
                );


            if (
                currentProject &&
                currentProject.id ===
                projectId
            ) {

                this.core.state.set(
                    "currentProject",
                    null
                );

            }


            this.core.events.emit(
                "project:deleted",
                existing
            );


            this.core.notify(
                `Project "${existing.name}" deleted.`,
                "success"
            );


            return true;

        }


        /*
        =====================================================
        SET CURRENT PROJECT
        =====================================================
        */

        setCurrent(project) {

            if (
                project === null
            ) {

                this.core.state.set(
                    "currentProject",
                    null
                );

                return null;

            }


            if (
                !AuthorOSProjectModel.validate(
                    project
                )
            ) {

                throw new Error(
                    "Invalid current project."
                );

            }


            this.core.state.set(
                "currentProject",
                project
            );


            return project;

        }


        /*
        =====================================================
        GET CURRENT PROJECT
        =====================================================
        */

        getCurrent() {

            return this.core.state.get(
                "currentProject"
            );

        }


        /*
        =====================================================
        SAVE PROJECT
        =====================================================
        */

        save(project) {

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
                this.getAll();


            const index =
                projects.findIndex(
                    item =>
                        item.id ===
                        project.id
                );


            if (index === -1) {

                projects.push(
                    project
                );

            } else {

                projects[index] =
                    project;

            }


            this.core.state.set(
                "projects",
                projects
            );


            this.core.state.set(
                "currentProject",
                project
            );


            this.core.storage.saveProjects(
                projects
            );


            this.core.events.emit(
                "project:saved",
                project
            );


            return true;

        }

    }


    window.AuthorOSProjectService =
        AuthorOSProjectService;

})();