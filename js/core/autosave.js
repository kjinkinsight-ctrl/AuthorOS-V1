/*
=========================================================
AUTHOROS
AUTOSAVE FOUNDATION
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    class AuthorOSAutosave {

        constructor(core) {

            this.core =
                core;

            this.enabled =
                true;

            this.debounceMs =
                1200;

            this.pendingTimer =
                null;

            this.dirty =
                false;

            this.isSaving =
                false;

            this.saveQueued =
                false;

            this.lastSaveError =
                null;

            this.dirtyProjectIds =
                new Set();

        }


        initialize() {

            this.start();

        }


        start() {

            this.enabled =
                true;

        }


        stop() {

            this.enabled =
                false;


            if (
                this.pendingTimer
            ) {

                window.clearTimeout(
                    this.pendingTimer
                );

                this.pendingTimer =
                    null;

            }

        }


        markDirty() {

            this.dirty =
                true;

            this.lastSaveError =
                null;


            this.core.events.emit(
                "autosave:dirty"
            );

        }


        markClean() {

            this.dirty =
                false;

            this.lastSaveError =
                null;

            this.dirtyProjectIds.clear();


            this.core.events.emit(
                "autosave:clean"
            );

        }


        queueProjectSave(
            projectId,
            options = {}
        ) {

            if (
                !this.enabled
            ) {

                return false;

            }


            if (
                typeof projectId === "string" &&
                projectId.trim()
            ) {

                this.dirtyProjectIds.add(
                    projectId.trim()
                );

            }


            this.markDirty();


            if (
                this.pendingTimer
            ) {

                window.clearTimeout(
                    this.pendingTimer
                );

                this.pendingTimer =
                    null;

            }


            this.pendingTimer =
                window.setTimeout(
                    () => {

                        this.pendingTimer =
                            null;


                        this.save({
                            reason:
                                options.reason ||
                                "debounced"
                        });

                    },
                    this.debounceMs
                );


            return true;

        }


        clearProjectDirty(projectId) {

            if (
                typeof projectId === "string" &&
                projectId.trim()
            ) {

                this.dirtyProjectIds.delete(
                    projectId.trim()
                );

            }


            if (
                this.dirtyProjectIds.size === 0
            ) {

                this.markClean();

            }

        }


        flush(options = {}) {

            if (
                this.pendingTimer
            ) {

                window.clearTimeout(
                    this.pendingTimer
                );

                this.pendingTimer =
                    null;

            }


            return this.save({
                reason:
                    options.reason ||
                    "flush"
            });

        }


        flushProject(
            projectId,
            options = {}
        ) {

            if (
                typeof projectId === "string" &&
                projectId.trim()
            ) {

                this.dirtyProjectIds.add(
                    projectId.trim()
                );

            }


            return this.flush({
                reason:
                    options.reason ||
                    "project-flush"
            });

        }


        removeProjectTracking(projectId) {

            if (
                typeof projectId !== "string" ||
                !projectId.trim()
            ) {

                return;

            }


            this.dirtyProjectIds.delete(
                projectId.trim()
            );


            if (
                this.dirtyProjectIds.size === 0 &&
                !this.isSaving
            ) {

                this.dirty =
                    false;

            }

        }


        save(options = {}) {

            if (
                !this.enabled ||
                !this.dirty
            ) {

                return false;

            }


            if (
                this.isSaving
            ) {

                this.saveQueued =
                    true;

                return false;

            }


            this.isSaving =
                true;


            this.core.events.emit(
                "autosave:saving",
                {
                    reason:
                        options.reason ||
                        "autosave"
                }
            );


            try {

                this.persistDirtyProjects();


                this.core.storage.saveSettings(
                    this.core.state.get(
                        "settings"
                    )
                );


                this.core.storage.saveCurrentView(
                    this.core.state.get(
                        "app.currentView"
                    )
                );


                this.markClean();


                window.setTimeout(
                    () => {

                        this.core.events.emit(
                            "autosave:completed",
                            {
                                reason:
                                    options.reason ||
                                    "autosave"
                            }
                        );

                    },
                    0
                );


                return true;


            } catch (error) {

                console.error(
                    "AuthorOS autosave failed:",
                    error
                );


                this.lastSaveError =
                    error;


                this.core.events.emit(
                    "autosave:error",
                    error
                );


                return false;


            } finally {

                this.isSaving =
                    false;


                if (
                    this.saveQueued
                ) {

                    const nextProjectId =
                        this.getNextDirtyProjectId() ||
                        this.getActiveProjectId();

                    this.saveQueued =
                        false;

                    this.queueProjectSave(
                        nextProjectId,
                        {
                            reason:
                                "queued"
                        }
                    );

                }

            }

        }


        getActiveProjectId() {

            return this.core.state.get(
                "currentProject"
            )?.id || null;

        }


        persistDirtyProjects() {

            const projectIds =
                this.getProjectIdsToPersist();


            projectIds.forEach(
                projectId => {

                    const project =
                        this.core.state
                            .get(
                                "projects"
                            )
                            ?.find(
                                item =>
                                    item.id ===
                                    projectId
                            );


                    if (!project) {

                        this.dirtyProjectIds.delete(
                            projectId
                        );

                        return;

                    }


                    const stored =
                        this.core.storage.loadProject(
                            projectId
                        );


                    if (
                        stored &&
                        JSON.stringify(
                            stored
                        ) === JSON.stringify(
                            project
                        )
                    ) {

                        this.dirtyProjectIds.delete(
                            projectId
                        );

                        return;

                    }


                    const saved =
                        this.core.storage.saveProject(
                            project
                        );


                    if (!saved) {

                        throw new Error(
                            `Autosave failed for project ${projectId}.`
                        );

                    }


                    this.dirtyProjectIds.delete(
                        projectId
                    );

                }
            );


            if (
                this.dirtyProjectIds.size > 0
            ) {

                throw new Error(
                    "Autosave left pending project changes."
                );

            }

        }


        getProjectIdsToPersist() {

            const activeProjectId =
                this.getActiveProjectId();

            const dirtyIds = [
                ...this.dirtyProjectIds
            ];


            if (
                activeProjectId &&
                dirtyIds.includes(
                    activeProjectId
                )
            ) {

                return [
                    activeProjectId,
                    ...dirtyIds.filter(
                        id =>
                            id !==
                            activeProjectId
                    )
                ];

            }


            if (
                dirtyIds.length > 0
            ) {

                return dirtyIds;

            }


            return activeProjectId
                ? [
                    activeProjectId
                ]
                : [];

        }


        getNextDirtyProjectId() {

            return this.dirtyProjectIds
                .values()
                .next()
                .value || null;

        }

    }


    window.AuthorOSAutosave =
        AuthorOSAutosave;

})();