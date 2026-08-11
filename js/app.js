/*
=========================================================
AUTHOROS
APPLICATION BOOTSTRAP
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    const AuthorOS = {

        core: null,

        sidebar: null,

        modal: null,

        search: null,

        tutorial: null,


        /*
        =====================================================
        INITIALIZATION
        =====================================================
        */

        initialize() {

            try {

                this.core =
                    new AuthorOSCore();


                this.core.storage =
                    new AuthorOSStorage();


                this.core.navigation =
                    new AuthorOSNavigation(
                        this.core
                    );


                this.sidebar =
                    new AuthorOSSidebar(
                        this.core
                    );

                this.core.sidebar =
                    this.sidebar;


                this.modal =
                    new AuthorOSModal();

                this.core.modal =
                    this.modal;


                this.search =
                    new AuthorOSSearch(
                        this.core
                    );

                this.core.searchService =
                    this.search;

                this.core.statisticsService =
                    new AuthorOSStatisticsService(
                        this.core
                    );

                this.core.backupExportService =
                    new AuthorOSBackupExportService(
                        this.core
                    );

                this.core.settingsService =
                    new AuthorOSSettingsService(
                        this.core
                    );

                this.tutorial =
                    new AuthorOSTutorialService(
                        this.core
                    );

                this.core.tutorialService =
                    this.tutorial;


                this.setupGlobalEvents();

                this.loadPersistedState();

                this.registerModules();

                this.registerRoutes();

                this.setupToolbar();

                this.setupSidebar();

                this.setupKeyboardShortcuts();

                this.setupStorageStatus();

                this.core.initialize();

                this.core.tutorialService?.initialize?.();

                this.core.settingsService.applySettings(
                    this.core.state.get(
                        "settings"
                    )
                );

                this.core.navigation.start(
                    this.core.settingsService.getInitialRoute() ||
                    this.core.state.get(
                        "app.currentView"
                    ) || "dashboard"
                );

                this.updateVersionDisplay();

                this.core.setStatus(
                    "Author Studio ready"
                );

                this.core.events.emit(
                    "app:ready"
                );

                this.core.tutorialService?.startIfNeeded?.();


                console.info(
                    `Author Studio v${this.core.getVersion()} initialized successfully.`
                );


                this.runStartupDiagnostics();


            } catch (error) {

                console.error(
                    "Author Studio startup error:",
                    error
                );


                this.showFatalError(
                    error
                );

            }

        },


        /*
        =====================================================
        GLOBAL EVENTS
        =====================================================
        */

        setupGlobalEvents() {

            this.core.events.on(
                "notification",
                notification => {

                    this.showNotification(
                        notification.message,
                        notification.type
                    );

                }
            );


            this.core.events.on(
                "navigation:changed",
                navigation => {

                    if (
                        navigation.route ===
                        "project-workspace" &&
                        !this.core.autosave?.dirty
                    ) {

                        this.core.setStatus(
                            "Saved"
                        );

                        return;

                    }


                    this.core.setStatus(
                        `${navigation.title} workspace`
                    );

                }
            );


            this.core.events.on(
                "autosave:completed",
                () => {

                    this.core.setStatus(
                        "Saved"
                    );

                }
            );


            this.core.events.on(
                "autosave:saving",
                () => {

                    this.core.setStatus(
                        "Saving..."
                    );

                }
            );


            this.core.events.on(
                "autosave:dirty",
                () => {

                    this.core.setStatus(
                        "Unsaved changes"
                    );

                }
            );


            this.core.events.on(
                "autosave:error",
                () => {

                    this.core.setStatus(
                        "Save failed"
                    );

                }
            );


            this.core.events.on(
                "project:created",
                project => {

                    this.core.autosave.queueProjectSave(
                        project?.id,
                        {
                            reason:
                                "project-created"
                        }
                    );

                }
            );


            this.core.events.on(
                "project:updated",
                project => {

                    this.core.autosave.queueProjectSave(
                        project?.id,
                        {
                            reason:
                                "project-updated"
                        }
                    );

                }
            );


            this.core.events.on(
                "project:archived",
                project => {

                    this.core.autosave.queueProjectSave(
                        project?.id,
                        {
                            reason:
                                "project-archived"
                        }
                    );

                }
            );


            this.core.events.on(
                "project:unarchived",
                project => {

                    this.core.autosave.queueProjectSave(
                        project?.id,
                        {
                            reason:
                                "project-unarchived"
                        }
                    );

                }
            );


            this.core.events.on(
                "project:deleted",
                project => {

                    this.core.autosave.removeProjectTracking(
                        project?.id
                    );

                }
            );


            this.core.events.on(
                "storage:changed",
                () => {

                    this.updateStorageStatus();

                }
            );

        },


        /*
        =====================================================
        PERSISTED STATE
        =====================================================
        */

        loadPersistedState() {

            const settings =
                this.core.settingsService.loadSettings();


            const projects =
                this.core.storage.loadProjects();


            const ideas =
                this.core.storage.loadIdeas();


            const currentView =
                this.core.storage.loadCurrentView();


            this.core.state.set(
                "settings",
                settings
            );


            this.core.state.set(
                "projects",
                Array.isArray(
                    projects
                )
                    ? projects
                    : []
            );


            this.core.state.set(
                "ideas",
                Array.isArray(
                    ideas
                )
                    ? ideas
                    : []
            );


            this.core.state.set(
                "app.currentView",
                currentView
            );

        },


        /*
        =====================================================
        MODULE REGISTRATION
        =====================================================
        */

        registerModules() {

            const modules = [

                window.AuthorOSDashboard,

                window.AuthorOSProjects,

                window.AuthorOSIdeas,

                window.AuthorOSManuscript,

                window.AuthorOSChapters,

                window.AuthorOSCharacters,

                window.AuthorOSWorld,

                window.AuthorOSPlot,

                window.AuthorOSTimeline,

                window.AuthorOSNotes,

                window.AuthorOSUniversalSearch,

                window.AuthorOSStatistics,

                window.AuthorOSBackupExport,

                window.AuthorOSSettings

            ];


            modules.forEach(
                module => {

                    if (!module) {
                        return;
                    }


                    this.core.registry.register(
                        module.name,
                        module
                    );

                }
            );


            this.core.registry.initializeAll(
                this.core
            );

        },


        /*
        =====================================================
        ROUTES
        =====================================================
        */

        registerRoutes() {

            const navigation =
                this.core.navigation;


            navigation.register(
                "dashboard",
                {

                    title:
                        "Dashboard",


                    render:
                        container => {

                            const projectCount =
                                this.core.state.get(
                                    "projects"
                                ).length;

                            const projects =
                                this.core.state.get(
                                    "projects"
                                );

                            const characterSummary =
                                (Array.isArray(projects)
                                    ? projects
                                    : [])
                                    .reduce(
                                        (acc, project) => {

                                            const characters =
                                                Array.isArray(project?.story?.characters)
                                                    ? project.story.characters
                                                    : [];

                                            acc.total +=
                                                characters.length;

                                            acc.active +=
                                                characters.filter(
                                                    character => String(character?.status || "") !== "Archived"
                                                ).length;

                                            return acc;

                                        },
                                        {
                                            total: 0,
                                            active: 0
                                        }
                                    );

                            const worldSummary =
                                (Array.isArray(projects)
                                    ? projects
                                    : [])
                                    .reduce(
                                        (acc, project) => {

                                            const entries =
                                                Array.isArray(project?.story?.worldEntries)
                                                    ? project.story.worldEntries
                                                    : [];

                                            acc.total +=
                                                entries.length;

                                            acc.active +=
                                                entries.filter(
                                                    entry => String(entry?.status || "") !== "Archived"
                                                ).length;

                                            return acc;

                                        },
                                        {
                                            total: 0,
                                            active: 0
                                        }
                                    );

                            const plotSummary =
                                (Array.isArray(projects)
                                    ? projects
                                    : [])
                                    .reduce(
                                        (acc, project) => {

                                            const plot =
                                                project?.story?.plot && typeof project.story.plot === "object"
                                                    ? project.story.plot
                                                    : null;

                                            const scenes =
                                                Array.isArray(plot?.scenes)
                                                    ? plot.scenes
                                                    : [];

                                            const arcs =
                                                Array.isArray(plot?.arcs)
                                                    ? plot.arcs
                                                    : [];

                                            acc.scenes +=
                                                scenes.length;

                                            acc.completedScenes +=
                                                scenes.filter(
                                                    scene => String(scene?.status || "") === "Complete"
                                                ).length;

                                            acc.arcs +=
                                                arcs.length;

                                            return acc;

                                        },
                                        {
                                            arcs: 0,
                                            scenes: 0,
                                            completedScenes: 0
                                        }
                                    );

                            const timelineSummary =
                                (Array.isArray(projects)
                                    ? projects
                                    : [])
                                    .reduce(
                                        (acc, project) => {

                                            const timeline =
                                                project?.story?.timeline &&
                                                typeof project.story.timeline === "object" &&
                                                !Array.isArray(project.story.timeline)
                                                    ? project.story.timeline
                                                    : null;

                                            const events =
                                                Array.isArray(timeline?.events)
                                                    ? timeline.events
                                                    : [];

                                            const eras =
                                                Array.isArray(timeline?.eras)
                                                    ? timeline.eras
                                                    : [];

                                            acc.events += events.length;
                                            acc.planned += events.filter(
                                                event => String(event?.status || "") === "Planned"
                                            ).length;
                                            acc.completed += events.filter(
                                                event => String(event?.status || "") === "Completed"
                                            ).length;
                                            acc.eras += eras.length;

                                            return acc;

                                        },
                                        {
                                            events: 0,
                                            planned: 0,
                                            completed: 0,
                                            eras: 0
                                        }
                                    );

                            const notesSummary =
                                (Array.isArray(projects)
                                    ? projects
                                    : [])
                                    .reduce(
                                        (acc, project) => {

                                            const notesStudio =
                                                project?.story?.notesStudio &&
                                                typeof project.story.notesStudio === "object"
                                                    ? project.story.notesStudio
                                                    : null;

                                            const records =
                                                Array.isArray(notesStudio?.records)
                                                    ? notesStudio.records
                                                    : [];

                                            const sources =
                                                Array.isArray(notesStudio?.sources)
                                                    ? notesStudio.sources
                                                    : [];

                                            acc.notes += records.filter(
                                                record => String(record?.type || "") === "Note"
                                            ).length;

                                            acc.research += records.filter(
                                                record => String(record?.type || "") === "Research"
                                            ).length;

                                            acc.sources += sources.length;

                                            return acc;

                                        },
                                        {
                                            notes: 0,
                                            research: 0,
                                            sources: 0
                                        }
                                    );

                            const ideasModule =
                                this.core.registry.get(
                                    "ideas"
                                );

                            const ideaSummary =
                                ideasModule &&
                                typeof ideasModule.getIdeaSummaryCounts === "function"
                                    ? ideasModule.getIdeaSummaryCounts()
                                    : {
                                        total: 0,
                                        draft: 0,
                                        developing: 0,
                                        ready: 0
                                    };

                            const recentBackupExport =
                                this.core.storage.get(
                                    "backupExportRecent",
                                    null
                                );

                            const settings =
                                this.core.state.get("settings") ||
                                this.core.settingsService.loadSettings();

                            const dashboardBackground =
                                settings?.appearance?.dashboardBackground &&
                                typeof settings.appearance.dashboardBackground === "object"
                                    ? settings.appearance.dashboardBackground
                                    : {
                                        image: null,
                                        position: "center",
                                        size: "cover"
                                    };

                            const dashboardBackgroundStyle =
                                this.getDashboardBackgroundStyle(
                                    dashboardBackground
                                );

                            const hasDashboardBackground =
                                Boolean(dashboardBackground?.image?.dataUrl);

                            const recentProjects =
                                (Array.isArray(projects) ? projects : [])
                                    .filter(project => String(project?.status || "") !== "Archived")
                                    .slice(0, 4);

                            const recentProjectTiles =
                                recentProjects
                                    .map(project => this.renderDashboardProjectTile(project))
                                    .join("");


                            container.innerHTML = `

                                <section
                                    class="dashboard-view ${hasDashboardBackground ? "dashboard-view-custom-bg" : ""}"
                                    style="${dashboardBackgroundStyle}"
                                >

                                    <div
                                        class="page-heading"
                                    >

                                        <div>

                                            <p
                                                class="eyebrow"
                                            >
                                                AUTHOR STUDIO
                                            </p>

                                            <h1>
                                                Your writing workspace.
                                            </h1>

                                            <p
                                                class="page-description"
                                            >
                                                Welcome to the foundation of your authoring system.
                                            </p>

                                        </div>

                                    </div>


                                    <div
                                        class="dashboard-grid"
                                    >

                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ▣
                                            </div>

                                            <div>

                                                <h2>
                                                    Projects
                                                </h2>

                                                <p>
                                                    ${projectCount}
                                                    project${projectCount === 1 ? "" : "s"}
                                                    currently stored.
                                                </p>

                                            </div>

                                        </article>


                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ▤
                                            </div>

                                            <div>

                                                <h2>
                                                    Manuscript
                                                </h2>

                                                <p>
                                                    Your writing workspace will become the heart
                                                    of Author Studio.
                                                </p>

                                            </div>

                                        </article>


                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ◇
                                            </div>

                                            <div>

                                                <h2>
                                                    Story
                                                </h2>

                                                <p>
                                                    ${characterSummary.active}
                                                    active characters |
                                                    ${characterSummary.total}
                                                    total profiles |
                                                    ${worldSummary.active}
                                                    active world entries |
                                                    ${worldSummary.total}
                                                    total world entries |
                                                    ${plotSummary.arcs}
                                                    arcs |
                                                    ${plotSummary.completedScenes}/${plotSummary.scenes}
                                                    scenes complete |
                                                    ${timelineSummary.events}
                                                    timeline events |
                                                    ${timelineSummary.completed}/${timelineSummary.planned}
                                                    completed/planned |
                                                    ${notesSummary.notes}
                                                    notes |
                                                    ${notesSummary.research}
                                                    research |
                                                    ${notesSummary.sources}
                                                    sources.
                                                </p>

                                            </div>

                                        </article>


                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ✦
                                            </div>

                                            <div>

                                                <h2>
                                                    Ideas
                                                </h2>

                                                <p>
                                                    ${ideaSummary.total}
                                                    total |
                                                    ${ideaSummary.draft}
                                                    draft |
                                                    ${ideaSummary.developing}
                                                    developing |
                                                    ${ideaSummary.ready}
                                                    ready
                                                </p>

                                            </div>

                                        </article>


                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ⌕
                                            </div>

                                            <div>

                                                <h2>
                                                    Universal Search
                                                </h2>

                                                <p>
                                                    Find projects, manuscript content, story entities, and research instantly.
                                                </p>

                                                <button
                                                    type="button"
                                                    class="button button-secondary"
                                                    data-action="dashboard-open-search"
                                                >
                                                    Open Search
                                                </button>

                                            </div>

                                        </article>


                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ◫
                                            </div>

                                            <div>

                                                <h2>
                                                    Statistics Studio
                                                </h2>

                                                <p>
                                                    Review manuscript, story, timeline, and notes analytics from canonical data.
                                                </p>

                                                <button
                                                    type="button"
                                                    class="button button-secondary"
                                                    data-action="dashboard-open-statistics"
                                                >
                                                    Open Statistics
                                                </button>

                                            </div>

                                        </article>


                                        <article
                                            class="dashboard-card"
                                        >

                                            <div
                                                class="card-icon"
                                            >
                                                ⛁
                                            </div>

                                            <div>

                                                <h2>
                                                    Backup &amp; Export
                                                </h2>

                                                <p>
                                                    ${recentBackupExport
                                                        ? `Last export: ${this.escapeHTML(recentBackupExport.fileName || "Backup")}`
                                                        : "Create full backups, project exports, and safe import previews."
                                                    }
                                                </p>

                                                <button
                                                    type="button"
                                                    class="button button-secondary"
                                                    data-action="dashboard-open-backup-export"
                                                >
                                                    Open Backup &amp; Export
                                                </button>

                                            </div>

                                        </article>

                                    </div>

                                    <section class="dashboard-project-showcase">
                                        <div class="dashboard-project-showcase-header">
                                            <h2>
                                                Recent Projects
                                            </h2>
                                            <button
                                                type="button"
                                                class="button button-secondary"
                                                data-action="dashboard-open-projects"
                                            >
                                                Open Story Library
                                            </button>
                                        </div>

                                        ${recentProjects.length
                                            ? `
                                                <div class="dashboard-project-showcase-grid">
                                                    ${recentProjectTiles}
                                                </div>
                                            `
                                            : `
                                                <p class="dashboard-project-showcase-empty">
                                                    No projects yet. Create your first story in the Story Library.
                                                </p>
                                            `
                                        }
                                    </section>


                                    <section
                                        class="foundation-status"
                                    >

                                        <div
                                            class="foundation-status-header"
                                        >

                                            <div>

                                                <p
                                                    class="eyebrow"
                                                >
                                                    FOUNDATION
                                                </p>

                                                <h2>
                                                    Author Studio is online.
                                                </h2>

                                            </div>

                                            <span
                                                class="status-pill"
                                            >
                                                READY
                                            </span>

                                        </div>

                                        <p>
                                            The Author Studio foundation is operational.
                                            Core services, persistence, navigation,
                                            modules and diagnostics are active.
                                        </p>

                                    </section>

                                </section>

                            `;

                            container
                                .querySelector('[data-action="dashboard-open-search"]')
                                ?.addEventListener(
                                    "click",
                                    event => {

                                        event.preventDefault();

                                        this.core.navigation.navigate(
                                            "search"
                                        );

                                        const searchModule =
                                            this.core.registry.get(
                                                "universal-search"
                                            );

                                        searchModule?.focusInput?.();

                                    }
                                );

                            container
                                .querySelector('[data-action="dashboard-open-statistics"]')
                                ?.addEventListener(
                                    "click",
                                    event => {

                                        event.preventDefault();

                                        this.core.navigation.navigate(
                                            "statistics"
                                        );

                                    }
                                );

                            container
                                .querySelector('[data-action="dashboard-open-backup-export"]')
                                ?.addEventListener(
                                    "click",
                                    event => {

                                        event.preventDefault();

                                        this.core.navigation.navigate(
                                            "backup-export"
                                        );

                                    }
                                );

                            container
                                .querySelector('[data-action="dashboard-open-projects"]')
                                ?.addEventListener(
                                    "click",
                                    event => {

                                        event.preventDefault();

                                        this.core.navigation.navigate(
                                            "projects"
                                        );

                                    }
                                );

                        }

                }

            );


            navigation.register(
                "search",
                {

                    title:
                        "Universal Search",

                    render:
                        container => {

                            const searchModule =
                                this.core.registry.get(
                                    "universal-search"
                                );

                            if (!searchModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Universal Search</h1>
                                        <p>Search services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Universal Search is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            searchModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "statistics",
                {

                    title:
                        "Statistics Studio",

                    render:
                        container => {

                            const statisticsModule =
                                this.core.registry.get(
                                    "statistics"
                                );

                            if (!statisticsModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Statistics Studio</h1>
                                        <p>Statistics services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Statistics Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            statisticsModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "backup-export",
                {

                    title:
                        "Backup & Export Studio",

                    render:
                        container => {

                            const backupExportModule =
                                this.core.registry.get(
                                    "backup-export"
                                );

                            if (!backupExportModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Backup &amp; Export Studio</h1>
                                        <p>Backup and export services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Backup & Export Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            backupExportModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "projects",
                {

                    title:
                        "Story Library",

                    render:
                        container => {

                            const projectsModule =
                                this.core.registry.get(
                                    "projects"
                                );


                            if (!projectsModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Story Library</h1>
                                        <p>Project services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Story Library is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            projectsModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "ideas",
                {

                    title:
                        "Ideas Library",

                    render:
                        container => {

                            const ideasModule =
                                this.core.registry.get(
                                    "ideas"
                                );


                            if (!ideasModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Ideas Library</h1>
                                        <p>Ideas services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Ideas Library is unavailable.",
                                    "error"
                                );

                                return;

                            }


                            ideasModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "characters",
                {

                    title:
                        "Character Studio",

                    render:
                        container => {

                            const charactersModule =
                                this.core.registry.get(
                                    "characters"
                                );


                            if (!charactersModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Character Studio</h1>
                                        <p>Character services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Character Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            charactersModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "world",
                {

                    title:
                        "World Studio",

                    render:
                        container => {

                            const worldModule =
                                this.core.registry.get(
                                    "world"
                                );


                            if (!worldModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>World Studio</h1>
                                        <p>World Studio services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "World Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            worldModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "plot",
                {

                    title:
                        "Plot Studio",

                    render:
                        container => {

                            const plotModule =
                                this.core.registry.get(
                                    "plot"
                                );


                            if (!plotModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Plot Studio</h1>
                                        <p>Plot Studio services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Plot Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            plotModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "timeline",
                {

                    title:
                        "Timeline Studio",

                    render:
                        container => {

                            const timelineModule =
                                this.core.registry.get(
                                    "timeline"
                                );


                            if (!timelineModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Timeline Studio</h1>
                                        <p>Timeline Studio services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Timeline Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            timelineModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "notes",
                {

                    title:
                        "Notes & Research Studio",

                    render:
                        container => {

                            const notesModule =
                                this.core.registry.get(
                                    "notes"
                                );


                            if (!notesModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Notes &amp; Research Studio</h1>
                                        <p>Notes services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Notes & Research Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            notesModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "project-workspace",
                {

                    title:
                        "Project Workspace",

                    render:
                        container => {

                            const projectsModule =
                                this.core.registry.get(
                                    "projects"
                                );


                            if (!projectsModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Project Workspace</h1>
                                        <p>Project workspace services are unavailable.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Project workspace is unavailable.",
                                    "error"
                                );

                                return;

                            }


                            projectsModule.renderProjectWorkspace(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "manuscript",
                {

                    title:
                        "Manuscript Studio",

                    render:
                        container => {

                            const manuscriptModule =
                                this.core.registry.get(
                                    "manuscript"
                                );


                            if (!manuscriptModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Manuscript Studio</h1>
                                        <p>Manuscript services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Manuscript Studio is unavailable.",
                                    "error"
                                );

                                return;

                            }


                            manuscriptModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "chapters",
                {

                    title:
                        "Chapters",

                    render:
                        container => {

                            const chaptersModule =
                                this.core.registry.get(
                                    "chapters"
                                );


                            if (!chaptersModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Chapters</h1>
                                        <p>Chapter services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Chapters is unavailable.",
                                    "error"
                                );

                                return;

                            }


                            chaptersModule.render(
                                container
                            );

                        }

                }
            );


            navigation.register(
                "settings",
                {

                    title:
                        "Settings",

                    render:
                        container => {

                            const settingsModule =
                                this.core.registry.get(
                                    "settings"
                                );

                            if (!settingsModule) {

                                container.innerHTML = `

                                    <section class="empty-view">
                                        <div class="empty-view-icon">◇</div>
                                        <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                                        <h1>Settings</h1>
                                        <p>Settings services are unavailable right now.</p>
                                    </section>

                                `;

                                this.core.notify(
                                    "Settings is unavailable.",
                                    "error"
                                );

                                return;

                            }

                            settingsModule.render(
                                container
                            );

                        }

                }
            );

        },


        /*
        =====================================================
        TOOLBAR
        =====================================================
        */

        setupToolbar() {

            const sidebarButton =
                document.getElementById(
                    "sidebar-toggle"
                );


            if (sidebarButton) {

                sidebarButton.addEventListener(
                    "click",
                    () => {

                        this.sidebar.toggle();

                    }
                );

            }


            const themeButton =
                document.getElementById(
                    "theme-button"
                );


            if (themeButton) {

                themeButton.addEventListener(
                    "click",
                    () => {

                        this.toggleTheme();

                    }
                );

            }


            const notificationButton =
                document.getElementById(
                    "notification-button"
                );

            const globalSearchButton =
                document.getElementById(
                    "global-search-button"
                );


            if (notificationButton) {

                notificationButton.addEventListener(
                    "click",
                    () => {

                        this.core.notify(
                            "No new notifications.",
                            "info"
                        );

                    }
                );

            }


            if (globalSearchButton) {

                globalSearchButton.addEventListener(
                    "click",
                    () => {

                        this.core.navigation.navigate(
                            "search"
                        );

                        const searchModule =
                            this.core.registry.get(
                                "universal-search"
                            );

                        searchModule?.focusInput?.();

                    }
                );

            }

        },


        /*
        =====================================================
        SIDEBAR
        =====================================================
        */

        setupSidebar() {

            document
                .querySelectorAll(
                    "[data-route]"
                )
                .forEach(
                    item => {

                        item.addEventListener(
                            "click",
                            () => {

                                const route =
                                    item.dataset.route;


                                this.core.navigation.navigate(
                                    route
                                );

                            }
                        );

                    }
                );


            if (
                this.core.state.get(
                    "ui.sidebarCollapsed"
                )
            ) {

                this.sidebar.collapse();

            }

        },


        /*
        =====================================================
        KEYBOARD SHORTCUTS
        =====================================================
        */

        setupKeyboardShortcuts() {

            const settingsService =
                this.core.settingsService;

            document.addEventListener(
                "keydown",
                event => {

                    if (
                        event.key ===
                        "Escape"
                    ) {

                        if (
                            this.modal?.container
                                ?.classList
                                .contains(
                                    "active"
                                )
                        ) {

                            this.modal.close();

                            event.preventDefault();

                            return;

                        }

                    }


                    if (
                        settingsService.isShortcutMatch(
                            event,
                            "openSearch"
                        )
                    ) {

                        if (
                            this.isEditableElement(
                                event.target
                            )
                        ) {

                            return;

                        }

                        event.preventDefault();

                        this.core.navigation.navigate(
                            "search"
                        );

                        const searchModule =
                            this.core.registry.get(
                                "universal-search"
                            );

                        searchModule?.focusInput?.();

                        return;

                    }


                    if (
                        settingsService.isShortcutMatch(
                            event,
                            "openDashboard"
                        )
                    ) {

                        if (
                            this.isEditableElement(
                                event.target
                            )
                        ) {
                            return;
                        }

                        event.preventDefault();

                        this.core.navigation.navigate(
                            "dashboard"
                        );

                    }


                    if (
                        (event.ctrlKey ||
                         event.metaKey) &&
                        !event.shiftKey &&
                        event.key.toLowerCase() ===
                        "s"
                    ) {

                        event.preventDefault();

                        const saved =
                            this.core.autosave.flush({
                                reason:
                                    "manual-save"
                            });


                        if (saved) {

                            this.core.notify(
                                "Project changes saved.",
                                "success"
                            );

                        }

                    }


                    if (
                        settingsService.isShortcutMatch(
                            event,
                            "openSettings"
                        )
                    ) {

                        if (
                            this.isEditableElement(
                                event.target
                            )
                        ) {
                            return;
                        }

                        event.preventDefault();

                        this.core.navigation.navigate(
                            "settings"
                        );

                        return;

                    }


                    if (
                        settingsService.isShortcutMatch(
                            event,
                            "openBackupExport"
                        )
                    ) {

                        if (
                            this.isEditableElement(
                                event.target
                            )
                        ) {
                            return;
                        }

                        event.preventDefault();

                        this.core.navigation.navigate(
                            "backup-export"
                        );

                    }

                }
            );

        },


        isEditableElement(target) {

            const element =
                target && target.nodeType === 1
                    ? target
                    : null;

            if (!element) {
                return false;
            }

            if (
                element.closest(
                    "input, textarea, select, [contenteditable='true']"
                )
            ) {
                return true;
            }

            return false;

        },


        renderDashboardProjectTile(project) {

            const safeTitle =
                this.escapeHTML(
                    String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project"
                );

            const safeStatus =
                this.escapeHTML(
                    String(project?.status || "Draft").trim() || "Draft"
                );

            const safeType =
                this.escapeHTML(
                    String(project?.type || "Novel").trim() || "Novel"
                );

            const normalizedImage =
                window.AuthorOSImageAssets
                    ? window.AuthorOSImageAssets.normalizeStoredAsset(
                        project?.image,
                        {
                            maxStoredBytes: 1024 * 1024
                        }
                    )
                    : null;

            const media =
                normalizedImage?.dataUrl
                    ? `
                        <img
                            class="dashboard-project-tile-image"
                            src="${this.escapeHTML(normalizedImage.dataUrl)}"
                            alt="${safeTitle}"
                        />
                        <div class="dashboard-project-tile-image-overlay" aria-hidden="true"></div>
                    `
                    : `
                        <div class="dashboard-project-tile-fallback" aria-hidden="true">✦</div>
                    `;

            return `
                <article class="dashboard-project-tile">
                    <div class="dashboard-project-tile-media">
                        ${media}
                    </div>
                    <div class="dashboard-project-tile-body">
                        <h3>${safeTitle}</h3>
                        <p>
                            <span>${safeType}</span>
                            <span>${safeStatus}</span>
                        </p>
                    </div>
                </article>
            `;

        },


        getDashboardBackgroundStyle(dashboardBackground) {

            const normalized =
                this.core.settingsService
                    .normalizeDashboardBackground(
                        dashboardBackground
                    );

            if (!normalized.image?.dataUrl) {
                return "";
            }

            const position =
                this.escapeHTML(
                    normalized.position || "center"
                );

            const size =
                this.escapeHTML(
                    normalized.size || "cover"
                );

            const imageUrl =
                this.escapeHTML(
                    normalized.image.dataUrl
                );

            return `--dashboard-bg-image: url('${imageUrl}'); --dashboard-bg-position: ${position}; --dashboard-bg-size: ${size};`;

        },


        /*
        =====================================================
        THEME
        =====================================================
        */

        applyPersistedTheme() {

            this.core.settingsService.applyAppearance(
                this.core.state.get(
                    "settings"
                ) || this.core.settingsService.loadSettings()
            );

        },


        setTheme(theme) {

            const validThemes =
                this.core.settingsService
                    .getThemeRegistry()
                    .map(item => item.id);


            if (
                !validThemes.includes(
                    theme
                )
            ) {

                return;

            }


            this.core.state.set(
                "settings.appearance.theme",
                theme
            );

            this.core.settingsService.saveSettings(
                this.core.state.get(
                    "settings"
                )
            );


            const label =
                `${theme.charAt(0).toUpperCase()}${theme.slice(1)} theme`;


            this.core.setStatus(
                `${label} enabled`
            );


            this.core.events.emit(
                "storage:changed"
            );

        },


        toggleTheme() {

            const current =
                this.core.state.get(
                    "settings.appearance.theme"
                );


            let next;


            if (current === "paper" || current === "slate") {
                next = "obsidian";
            } else {
                next = "paper";
            }


            this.setTheme(
                next
            );

        },


        /*
        =====================================================
        STORAGE
        =====================================================
        */

        setupStorageStatus() {

            this.updateStorageStatus();

        },


        updateStorageStatus() {

            const element =
                document.getElementById(
                    "storage-status"
                );


            if (!element) {
                return;
            }


            element.textContent =
                this.core.storage.available
                    ? "Local storage"
                    : "Storage unavailable";

        },


        /*
        =====================================================
        DIAGNOSTICS
        =====================================================
        */

        runStartupDiagnostics() {

            const result =
                this.core.diagnose();


            const projectsModule =
                this.core.registry.get(
                    "projects"
                );


            if (
                projectsModule &&
                typeof projectsModule.verifyStorageSynchronization ===
                "function"
            ) {

                const sync =
                    projectsModule.verifyStorageSynchronization();


                const reportLine =
                    sync.synchronized
                        ? `[Storage Sync: PASS] state=${sync.stateCount} storage=${sync.storageCount}`
                        : `[Storage Sync: FAIL] state=${sync.stateCount} storage=${sync.storageCount}`;


                if (sync.synchronized) {

                    const now =
                        new Date();


                    const timestamp =
                        `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}:${String(now.getSeconds()).padStart(2, "0")}`;

                    console.info(
                        reportLine
                    );

                    this.core.setStatus(
                        `Storage sync verified at ${timestamp}`
                    );

                } else {

                    console.warn(
                        reportLine,
                        sync
                    );

                    this.core.setStatus(
                        "Storage sync mismatch"
                    );

                }

            }


            if (!result) {
                return;
            }


            const failed =
                result.checks.filter(
                    check =>
                        check.status ===
                        "failed"
                );


            if (
                failed.length > 0
            ) {

                console.warn(
                    "Author Studio foundation diagnostics:",
                    result
                );

                return;

            }


            console.info(
                "Author Studio foundation diagnostics passed:",
                result
            );

        },


        /*
        =====================================================
        VERSION
        =====================================================
        */

        updateVersionDisplay() {

            const version =
                this.core.getVersion();


            const appVersion =
                document.getElementById(
                    "app-version"
                );


            const statusVersion =
                document.getElementById(
                    "status-version"
                );


            if (appVersion) {

                appVersion.textContent =
                    `v${version}`;

            }


            if (statusVersion) {

                statusVersion.textContent =
                    `v${version}`;

            }

        },


        /*
        =====================================================
        NOTIFICATIONS
        =====================================================
        */

        showNotification(
            message,
            type = "info"
        ) {

            if (
                this.core?.settingsService &&
                !this.core.settingsService.shouldDisplayNotification(
                    message,
                    type
                )
            ) {
                return;
            }

            const container =
                document.getElementById(
                    "notification-container"
                );


            if (!container) {
                return;
            }


            const notification =
                document.createElement(
                    "div"
                );


            notification.className =
                `notification notification-${type}`;


            notification.textContent =
                message;


            container.appendChild(
                notification
            );


            window.setTimeout(
                () => {

                    notification.classList.add(
                        "notification-removing"
                    );


                    window.setTimeout(
                        () => {

                            notification.remove();

                        },
                        250
                    );

                },
                this.core?.settingsService
                    ? this.core.settingsService.getNotificationDuration()
                    : 3000
            );

        },


        /*
        =====================================================
        FATAL ERROR
        =====================================================
        */

        showFatalError(error) {

            const app =
                document.getElementById(
                    "authoros-app"
                );


            if (!app) {
                return;
            }


            app.innerHTML = `

                <div
                    class="fatal-error"
                >

                    <div
                        class="fatal-error-content"
                    >

                        <div
                            class="fatal-error-icon"
                        >
                            !
                        </div>

                        <h1>
                            Author Studio could not start
                        </h1>

                        <p>
                            A startup error prevented the application
                            from loading.
                        </p>

                        <details>

                            <summary>
                                Technical details
                            </summary>

                            <pre>${this.escapeHTML(
                                error?.message ||
                                String(error)
                            )}</pre>

                        </details>

                    </div>

                </div>

            `;

        },


        /*
        =====================================================
        HTML ESCAPING
        =====================================================
        */

        escapeHTML(value) {

            return String(value)

                .replaceAll(
                    "&",
                    "&amp;"
                )

                .replaceAll(
                    "<",
                    "&lt;"
                )

                .replaceAll(
                    ">",
                    "&gt;"
                )

                .replaceAll(
                    '"',
                    "&quot;"
                )

                .replaceAll(
                    "'",
                    "&#039;"
                );

        }

    };


    /*
    =========================================================
    GLOBAL ERROR HANDLING
    =========================================================
    */

    window.addEventListener(
        "error",
        event => {

            console.error(
                "Author Studio runtime error:",
                event.error ||
                event.message
            );

        }
    );


    window.addEventListener(
        "unhandledrejection",
        event => {

            console.error(
                "Author Studio unhandled promise rejection:",
                event.reason
            );

        }
    );


    /*
    =========================================================
    CLEAN SHUTDOWN
    =========================================================
    */

    window.addEventListener(
        "beforeunload",
        event => {

            if (
                !window.AuthorOS?.core
            ) {

                return;

            }

            const shouldConfirm =
                window.AuthorOS.core.settingsService?.shouldConfirmBeforeExit?.() &&
                window.AuthorOS.core.autosave?.dirty;

            if (
                window.AuthorOS.core.autosave?.dirty
            ) {

                window.AuthorOS.core.autosave.flush({
                    reason: "before-unload"
                });

            }

            if (shouldConfirm) {

                event.preventDefault();
                event.returnValue = "";

                return;

            }

            window.AuthorOS.core.shutdown();

        }
    );


    window.AuthorOS =
        AuthorOS;


    document.addEventListener(
        "DOMContentLoaded",
        () => {

            AuthorOS.initialize();

        }
    );

})();
