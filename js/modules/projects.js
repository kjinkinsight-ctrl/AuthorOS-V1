/*
=========================================================
AUTHOROS
STORY LIBRARY MODULE
Milestone 01 — Batch 4
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";


    window.AuthorOSProjects = {

        name: "projects",

        core: null,

        container: null,

        modalContainer: null,

        editingProjectId: null,

        deletingProjectId: null,

        modalFormBaseline: null,

        modalFormDirty: false,

        projectImageDraft: null,

        deletingBackupId: null,

        restoringBackupId: null,

        backupSchemaVersion: 1,

        storageSync: {

            lastWriteVerifiedAt: null,

            lastReadVerifiedAt: null,

            lastRecoveredAt: null,

            malformedRecordsRecovered: 0,

            lastError: null

        },

        libraryFilters: {

            search: "",

            status: "all",

            genre: "all",

            type: "all",

            sort: "updated",

            showArchived: true

        },

        projectWorkspaceSection:
            "overview",


        /*
        =====================================================
        INITIALIZE
        =====================================================
        */

        initialize(core) {

            this.core = core;

            this.modalContainer =
                document.getElementById(
                    "modal-container"
                );


            this.synchronizeProjectsFromStorage();

        },


        /*
        =====================================================
        RENDER LIBRARY
        =====================================================
        */

        render(container) {

            if (!container) {

                return;

            }


            this.container =
                container;


            const projects =
                this.getProjects();


            const filteredProjects =
                this.getFilteredProjects(
                    projects
                );


            container.innerHTML = `

                <section class="library-view">

                    <header class="library-header">

                        <div class="library-heading">

                            <p class="eyebrow">
                                STORY LIBRARY
                            </p>

                            <h1>
                                Your Stories
                            </h1>

                            <p class="library-description">
                                Every story you write becomes part of your legacy.
                            </p>

                            ${this.renderGenreFamilyLegend()}

                        </div>


                        <div class="library-actions">

                            <button
                                type="button"
                                class="button button-primary"
                                data-action="new-project"
                            >
                                + New Project
                            </button>

                        </div>

                    </header>


                    ${this.renderLibraryControls()}


                    <div class="library-results-bar">

                        <span class="library-count">

                            ${
                                filteredProjects.length
                            }

                            ${
                                filteredProjects.length === 1
                                    ? "Project"
                                    : "Projects"
                            }

                        </span>


                        ${
                            this.hasActiveFilters()
                                ? `
                                    <span class="library-filter-state">
                                        Filtered from
                                        ${projects.length}
                                        ${
                                            projects.length === 1
                                                ? "project"
                                                : "projects"
                                        }
                                    </span>
                                `
                                : ""
                        }

                    </div>


                    ${
                        filteredProjects.length
                            ? this.renderProjectGrid(
                                filteredProjects
                            )
                            : this.renderNoResultsState()
                    }

                </section>

            `;


            this.bindLibraryEvents(
                container
            );

            this.bindFilterEvents(
                container
            );

        },


        /*
        =====================================================
        GET PROJECTS
        =====================================================
        */

        getProjects() {

            const projects =
                this.core.state.get(
                    "projects"
                );


            return Array.isArray(
                projects
            )
                ? projects
                : [];

        },


        /*
        =====================================================
        STORAGE SYNCHRONIZATION
        =====================================================
        */

        synchronizeProjectsFromStorage() {

            const storedProjects =
                this.core.storage.loadProjects();


            const report =
                this.normalizeProjectList(
                    storedProjects
                );


            this.core.state.set(
                "projects",
                report.projects
            );


            this.synchronizeCurrentProject(
                report.projects
            );


            if (
                !report.changed
            ) {

                this.storageSync.lastReadVerifiedAt =
                    new Date().toISOString();

                this.storageSync.lastError =
                    null;

                return;

            }


            const recovered =
                this.core.storage.saveProjects(
                    report.projects
                );


            if (!recovered) {

                this.storageSync.lastError =
                    "Unable to recover malformed project storage.";


                this.core.notify(
                    "Project storage recovery failed.",
                    "error"
                );

                return;

            }


            const now =
                new Date().toISOString();


            this.storageSync.lastReadVerifiedAt =
                now;

            this.storageSync.lastWriteVerifiedAt =
                now;

            this.storageSync.lastRecoveredAt =
                now;

            this.storageSync.malformedRecordsRecovered =
                report.recovered;

            this.storageSync.lastError =
                null;


            this.core.events.emit(
                "storage:changed"
            );


            this.core.setStatus(
                "Project storage recovered"
            );


            this.core.notify(
                "Recovered malformed project data from storage.",
                "info"
            );

        },


        verifyStorageSynchronization() {

            const stateReport =
                this.normalizeProjectList(
                    this.getProjects()
                );


            const storageReport =
                this.normalizeProjectList(
                    this.core.storage.loadProjects()
                );


            const synchronized =
                this.projectCollectionsMatch(
                    stateReport.projects,
                    storageReport.projects
                );


            if (synchronized) {

                this.storageSync.lastReadVerifiedAt =
                    new Date().toISOString();

                this.storageSync.lastError =
                    null;

            }


            return {

                synchronized,

                stateCount:
                    stateReport.projects.length,

                storageCount:
                    storageReport.projects.length,

                storageRecovered:
                    storageReport.recovered,

                changed:
                    storageReport.changed

            };

        },


        normalizeProjectList(projects) {

            const source =
                Array.isArray(projects)
                    ? projects
                    : [];


            const normalized = [];

            const seenIds =
                new Set();

            let recovered = 0;


            source.forEach(
                candidate => {

                    const project =
                        this.normalizeProject(
                            candidate
                        );


                    if (!project) {

                        recovered++;

                        return;

                    }


                    if (
                        seenIds.has(
                            project.id
                        )
                    ) {

                        recovered++;

                        project.id =
                            this.generateFallbackProjectId();

                    }


                    seenIds.add(
                        project.id
                    );

                    normalized.push(
                        project
                    );

                }
            );


            const changed =
                !this.projectCollectionsMatch(
                    source,
                    normalized
                );


            return {

                projects:
                    normalized,

                changed,

                recovered

            };

        },


        normalizeProject(project) {

            if (
                !project ||
                typeof project !==
                "object"
            ) {

                return null;

            }


            const title =
                String(
                    project.name ||
                    project.title ||
                    ""
                ).trim();


            const id =
                typeof project.id ===
                "string" &&
                project.id.trim()
                    ? project.id.trim()
                    : this.generateFallbackProjectId();


            const now =
                new Date().toISOString();


            const normalized = {

                ...project,

                id,

                name:
                    title ||
                    "Untitled Project",

                title:
                    title ||
                    "Untitled Project",

                author:
                    String(
                        project.author ||
                        ""
                    ).trim(),

                genre:
                    String(
                        project.genre ||
                        ""
                    ).trim(),

                type:
                    String(
                        project.type ||
                        "Novel"
                    ).trim() ||
                    "Novel",

                status:
                    String(
                        project.status ||
                        "Draft"
                    ).trim() ||
                    "Draft",

                series:
                    String(
                        project.series ||
                        ""
                    ).trim(),

                description:
                    String(
                        project.description ||
                        ""
                    ),

                image:
                    this.normalizeProjectImageAsset(
                        project.image
                    ),

                targetWords:
                    Math.max(
                        0,
                        Number.isFinite(
                            Number(
                                project.targetWords ??
                                project.targetWordCount
                            )
                        )
                            ? Number(
                                project.targetWords ??
                                project.targetWordCount
                            )
                            : 100000
                    ),

                targetWordCount:
                    Math.max(
                        0,
                        Number.isFinite(
                            Number(
                                project.targetWords ??
                                project.targetWordCount
                            )
                        )
                            ? Number(
                                project.targetWords ??
                                project.targetWordCount
                            )
                            : 100000
                    ),

                createdAt:
                    this.normalizeProjectDate(
                        project.createdAt,
                        now
                    ),

                updatedAt:
                    this.normalizeProjectDate(
                        project.updatedAt ||
                        project.lastModified,
                        now
                    ),

                lastModified:
                    this.normalizeProjectDate(
                        project.lastModified ||
                        project.updatedAt,
                        now
                    ),

                lastOpened:
                    this.normalizeProjectDate(
                        project.lastOpened,
                        null
                    ),

                statistics:
                    this.normalizeProjectStatistics(
                        project.statistics
                    ),

                manuscript: {

                    chapters:
                        Array.isArray(
                            project.manuscript?.chapters
                        )
                            ? project.manuscript.chapters
                            : []

                }

            };


            return normalized;

        },


        normalizeProjectImageAsset(image) {

            if (!window.AuthorOSImageAssets) {
                return null;
            }

            return window.AuthorOSImageAssets.normalizeStoredAsset(
                image,
                {
                    maxStoredBytes: 1024 * 1024
                }
            );

        },


        normalizeProjectDate(
            value,
            fallback
        ) {

            if (
                value === null ||
                value === undefined ||
                value === ""
            ) {

                return fallback;

            }


            const date =
                new Date(value);


            if (
                Number.isNaN(
                    date.getTime()
                )
            ) {

                return fallback;

            }


            return date.toISOString();

        },


        normalizeProjectStatistics(statistics) {

            const source =
                statistics &&
                typeof statistics ===
                "object"
                    ? statistics
                    : {};


            return {

                words:
                    Math.max(
                        0,
                        Number(
                            source.words || 0
                        ) || 0
                    ),

                characters:
                    Math.max(
                        0,
                        Number(
                            source.characters || 0
                        ) || 0
                    ),

                chapters:
                    Math.max(
                        0,
                        Number(
                            source.chapters || 0
                        ) || 0
                    ),

                scenes:
                    Math.max(
                        0,
                        Number(
                            source.scenes || 0
                        ) || 0
                    ),

                world:
                    Math.max(
                        0,
                        Number(
                            source.world || 0
                        ) || 0
                    ),

                plot:
                    Math.max(
                        0,
                        Number(
                            source.plot || 0
                        ) || 0
                    ),

                plotScenes:
                    Math.max(
                        0,
                        Number(
                            source.plotScenes || 0
                        ) || 0
                    ),

                timeline:
                    Math.max(
                        0,
                        Number(
                            source.timeline || 0
                        ) || 0
                    ),

                timelineEras:
                    Math.max(
                        0,
                        Number(
                            source.timelineEras || 0
                        ) || 0
                    ),

                notesCount:
                    Math.max(
                        0,
                        Number(
                            source.notesCount || 0
                        ) || 0
                    ),

                researchCount:
                    Math.max(
                        0,
                        Number(
                            source.researchCount || 0
                        ) || 0
                    ),

                sourcesCount:
                    Math.max(
                        0,
                        Number(
                            source.sourcesCount || 0
                        ) || 0
                    )

            };

        },


        generateFallbackProjectId() {

            return (
                "project-" +
                Date.now().toString(36) +
                "-" +
                Math.random()
                    .toString(36)
                    .slice(2, 8)
            );

        },


        synchronizeCurrentProject(projects) {

            const activeProjectId =
                this.core.storage.loadActiveProjectId();

            const currentProject =
                this.core.state.get(
                    "currentProject"
                );


            const preferredId =
                activeProjectId ||
                currentProject?.id ||
                null;


            if (!preferredId) {

                this.core.state.set(
                    "currentProject",
                    null
                );

                this.core.storage.saveActiveProjectId(
                    null
                );

                return;

            }


            const synced =
                projects.find(
                    project =>
                        project.id ===
                        preferredId
                ) || null;


            this.core.state.set(
                "currentProject",
                synced
            );


            this.core.storage.saveActiveProjectId(
                synced?.id ||
                null
            );

        },


        projectCollectionsMatch(
            a,
            b
        ) {

            const left =
                Array.isArray(a)
                    ? a
                    : [];

            const right =
                Array.isArray(b)
                    ? b
                    : [];


            if (
                left.length !==
                right.length
            ) {

                return false;

            }


            return JSON.stringify(
                left
            ) === JSON.stringify(
                right
            );

        },


        /*
        =====================================================
        FIND PROJECT
        =====================================================
        */

        getProject(projectId) {

            return this.getProjects()
                .find(
                    project =>
                        project.id ===
                        projectId
                );

        },


        getActiveProject() {

            const currentProject =
                this.core.state.get(
                    "currentProject"
                );


            if (
                currentProject &&
                typeof currentProject ===
                "object"
            ) {

                return currentProject;

            }


            const activeProjectId =
                this.core.storage.loadActiveProjectId();


            if (!activeProjectId) {

                return null;

            }


            const project =
                this.getProject(
                    activeProjectId
                ) || null;


            this.core.state.set(
                "currentProject",
                project
            );


            return project;

        },


        renderProjectWorkspace(container) {

            if (!container) {

                return;

            }


            this.container =
                container;


            const project =
                this.getActiveProject();


            if (!project) {

                container.innerHTML =
                    this.renderProjectWorkspaceEmptyState();

                this.bindProjectWorkspaceEvents(
                    container,
                    null
                );

                return;

            }


            const title =
                this.escapeHTML(
                    this.getProjectTitle(
                        project
                    )
                );


            const status =
                this.escapeHTML(
                    project.status ||
                    "Draft"
                );


            const type =
                this.escapeHTML(
                    project.type ||
                    "Project"
                );


            const lastModified =
                this.formatProjectDate(
                    project.lastModified ||
                    project.updatedAt
                );


            const createdAt =
                this.formatProjectDate(
                    project.createdAt
                );


            const wordCount =
                this.getProjectWordCount(
                    project
                ).toLocaleString();


            const workspaceSections = [

                ["overview", "Overview"],

                ["manuscript", "Manuscript"],

                ["characters", "Characters"],

                ["world", "World"],

                ["plot", "Plot"],

                ["timeline", "Timeline"],

                ["notes", "Notes"],

                ["research", "Research"],

                ["backups", "Backups"],

                ["settings", "Settings"]

            ];


            const activeSection =
                this.projectWorkspaceSection ||
                "overview";


            container.innerHTML = `

                <section class="project-workspace-view">

                    <header class="project-workspace-header">

                        <div class="project-workspace-heading">

                            <p class="eyebrow">
                                ACTIVE PROJECT
                            </p>

                            <h1 title="${title}">
                                ${title}
                            </h1>

                            <p class="project-workspace-subtitle">
                                ${type} | ${status}
                            </p>

                        </div>


                        <div class="project-workspace-header-actions">

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="return-to-library"
                            >
                                Return to Story Library
                            </button>

                        </div>

                    </header>


                    <section class="project-workspace-meta-grid">

                        <article class="project-workspace-meta-card">
                            <h2>Last Modified</h2>
                            <p>${lastModified}</p>
                        </article>

                        <article class="project-workspace-meta-card">
                            <h2>Created</h2>
                            <p>${createdAt}</p>
                        </article>

                        <article class="project-workspace-meta-card">
                            <h2>Word Count</h2>
                            <p>${wordCount} words</p>
                        </article>

                    </section>


                    <nav
                        class="project-workspace-nav"
                        aria-label="Project workspace navigation"
                    >
                        ${workspaceSections
                            .map(
                                ([sectionId, label]) => `
                                    <button
                                        type="button"
                                        class="project-workspace-nav-item ${activeSection === sectionId ? "active" : ""}"
                                        data-workspace-section="${sectionId}"
                                    >
                                        ${label}
                                    </button>
                                `
                            )
                            .join("")}
                    </nav>


                    <section class="project-workspace-panel">
                        ${this.renderProjectWorkspaceSection(
                            activeSection,
                            project
                        )}
                    </section>

                </section>

            `;


            this.bindProjectWorkspaceEvents(
                container,
                project.id
            );

        },


        renderProjectWorkspaceSection(
            section,
            project
        ) {

            if (
                section ===
                "overview"
            ) {

                return this.renderProjectDashboard(
                    project
                );

            }


            if (
                section ===
                "characters"
            ) {

                return this.renderCharacterWorkspaceSection(
                    project
                );

            }


            if (
                section ===
                "world"
            ) {

                return this.renderWorldWorkspaceSection(
                    project
                );

            }


            if (
                section ===
                "plot"
            ) {

                return this.renderPlotWorkspaceSection(
                    project
                );

            }


            if (
                section ===
                "timeline"
            ) {

                return this.renderTimelineWorkspaceSection(
                    project
                );

            }


            if (
                section ===
                "notes"
            ) {

                return this.renderNotesWorkspaceSection(
                    project
                );

            }


            if (
                section ===
                "backups"
            ) {

                return this.renderBackupManager(
                    project
                );

            }


            return `

                <section class="project-workspace-coming-soon">
                    <p class="eyebrow">PROJECT WORKSPACE</p>
                    <h2>${this.escapeHTML(section.charAt(0).toUpperCase() + section.slice(1))}</h2>
                    <p>This area will be available in a future milestone.</p>
                </section>

            `;

        },


        renderCharacterWorkspaceSection(project) {

            const characters =
                Array.isArray(project?.story?.characters)
                    ? project.story.characters
                    : [];

            const activeCount =
                characters.filter(
                    character => String(character?.status || "") !== "Archived"
                ).length;

            const archivedCount =
                characters.filter(
                    character => String(character?.status || "") === "Archived"
                ).length;

            return `

                <section class="project-workspace-coming-soon project-character-overview">
                    <p class="eyebrow">CHARACTER STUDIO</p>
                    <h2>Character Workspace</h2>
                    <p>
                        ${activeCount}
                        active character${activeCount === 1 ? "" : "s"}
                        ${archivedCount > 0 ? ` | ${archivedCount} archived` : ""}
                    </p>
                    <button
                        type="button"
                        class="button button-primary"
                        data-action="open-character-studio"
                    >
                        Open Character Studio
                    </button>
                </section>

            `;

        },


        renderWorldWorkspaceSection(project) {

            const worldEntries =
                Array.isArray(project?.story?.worldEntries)
                    ? project.story.worldEntries
                    : [];

            const activeCount =
                worldEntries.filter(
                    entry => String(entry?.status || "") !== "Archived"
                ).length;

            const archivedCount =
                worldEntries.filter(
                    entry => String(entry?.status || "") === "Archived"
                ).length;

            return `

                <section class="project-workspace-coming-soon project-world-overview">
                    <p class="eyebrow">WORLD STUDIO</p>
                    <h2>World Workspace</h2>
                    <p>
                        ${activeCount}
                        active entr${activeCount === 1 ? "y" : "ies"}
                        ${archivedCount > 0 ? ` | ${archivedCount} archived` : ""}
                    </p>
                    <button
                        type="button"
                        class="button button-primary"
                        data-action="open-world-studio"
                    >
                        Open World Studio
                    </button>
                </section>

            `;

        },


        renderPlotWorkspaceSection(project) {

            const plot =
                project?.story?.plot && typeof project.story.plot === "object"
                    ? project.story.plot
                    : {};

            const arcs =
                Array.isArray(plot.arcs)
                    ? plot.arcs
                    : [];

            const scenes =
                Array.isArray(plot.scenes)
                    ? plot.scenes
                    : [];

            const completeScenes =
                scenes.filter(
                    scene => String(scene?.status || "") === "Complete"
                ).length;

            return `

                <section class="project-workspace-coming-soon project-plot-overview">
                    <p class="eyebrow">PLOT STUDIO</p>
                    <h2>Plot Workspace</h2>
                    <p>
                        ${arcs.length}
                        arc${arcs.length === 1 ? "" : "s"}
                        | ${completeScenes}/${scenes.length}
                        scene${scenes.length === 1 ? "" : "s"} complete
                    </p>
                    <button
                        type="button"
                        class="button button-primary"
                        data-action="open-plot-studio"
                    >
                        Open Plot Studio
                    </button>
                </section>

            `;

        },


        renderTimelineWorkspaceSection(project) {

            const timeline =
                project?.story?.timeline &&
                typeof project.story.timeline === "object" &&
                !Array.isArray(project.story.timeline)
                    ? project.story.timeline
                    : {};

            const events =
                Array.isArray(timeline.events)
                    ? timeline.events
                    : [];

            const eras =
                Array.isArray(timeline.eras)
                    ? timeline.eras
                    : [];

            const completed =
                events.filter(
                    event => String(event?.status || "") === "Completed"
                ).length;

            return `

                <section class="project-workspace-coming-soon project-timeline-overview">
                    <p class="eyebrow">TIMELINE STUDIO</p>
                    <h2>Timeline Workspace</h2>
                    <p>
                        ${events.length}
                        event${events.length === 1 ? "" : "s"}
                        | ${completed}/${events.length}
                        completed
                        | ${eras.length}
                        era${eras.length === 1 ? "" : "s"}
                    </p>
                    <button
                        type="button"
                        class="button button-primary"
                        data-action="open-timeline-studio"
                    >
                        Open Timeline Studio
                    </button>
                </section>

            `;

        },


        renderNotesWorkspaceSection(project) {

            const notesStudio =
                project?.story?.notesStudio &&
                typeof project.story.notesStudio === "object"
                    ? project.story.notesStudio
                    : {};

            const records =
                Array.isArray(notesStudio.records)
                    ? notesStudio.records
                    : [];

            const sources =
                Array.isArray(notesStudio.sources)
                    ? notesStudio.sources
                    : [];

            const notesCount =
                records.filter(
                    record => String(record?.type || "") === "Note"
                ).length;

            const researchCount =
                records.filter(
                    record => String(record?.type || "") === "Research"
                ).length;

            return `

                <section class="project-workspace-coming-soon project-notes-overview">
                    <p class="eyebrow">NOTES &amp; RESEARCH</p>
                    <h2>Notes Workspace</h2>
                    <p>
                        ${notesCount}
                        notes
                        | ${researchCount}
                        research
                        | ${sources.length}
                        sources
                    </p>
                    <button
                        type="button"
                        class="button button-primary"
                        data-action="open-notes-studio"
                    >
                        Open Notes &amp; Research
                    </button>
                </section>

            `;

        },


        renderProjectDashboard(project) {

            const summaryItems =
                this.getProjectSummaryItems(
                    project
                );


            return `

                <div class="project-dashboard-grid">

                    <article class="project-dashboard-card project-dashboard-card-summary">
                        <header class="project-dashboard-card-header">
                            <h2>Project Summary</h2>
                        </header>

                        <dl class="project-dashboard-summary-list">
                            ${summaryItems
                                .map(
                                    item => `
                                        <div>
                                            <dt>${this.escapeHTML(item.label)}</dt>
                                            <dd>${this.escapeHTML(item.value)}</dd>
                                        </div>
                                    `
                                )
                                .join("")}
                        </dl>

                        ${this.renderProjectDescription(project)}
                    </article>


                    <article class="project-dashboard-card project-dashboard-card-actions">
                        <header class="project-dashboard-card-header">
                            <h2>Quick Actions</h2>
                        </header>

                        <div class="project-dashboard-actions-grid">
                            <button
                                type="button"
                                class="button button-primary"
                                data-action="continue-manuscript"
                            >
                                Continue Manuscript
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-character-studio"
                            >
                                Character Studio
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-world-studio"
                            >
                                World Studio
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-plot-studio"
                            >
                                Plot Studio
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-timeline-studio"
                            >
                                Timeline Studio
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-notes-studio"
                            >
                                Notes &amp; Research
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="edit-project-details"
                            >
                                Edit Project Details
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="project-settings"
                            >
                                Open Settings
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-backup-manager"
                            >
                                Backup Manager
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="return-to-library"
                            >
                                View Story Library
                            </button>

                            <button
                                type="button"
                                class="button button-danger"
                                data-action="delete-project-details"
                            >
                                Delete Project
                            </button>
                        </div>
                    </article>


                    <article class="project-dashboard-card project-dashboard-card-progress">
                        <header class="project-dashboard-card-header">
                            <h2>Writing Progress</h2>
                        </header>

                        ${this.renderWritingProgress(project)}
                    </article>


                    <article class="project-dashboard-card project-dashboard-card-stats">
                        <header class="project-dashboard-card-header">
                            <h2>Project Statistics</h2>
                        </header>

                        ${this.renderProjectStatistics(project)}
                    </article>


                    <article class="project-dashboard-card project-dashboard-card-activity">
                        <header class="project-dashboard-card-header">
                            <h2>Recent Activity</h2>
                        </header>

                        ${this.renderRecentActivity(project)}
                    </article>

                </div>

            `;

        },


        renderBackupManager(project) {

            const backups =
                this.getProjectBackups(
                    project.id
                );


            const latestBackup =
                backups[0] || null;


            return `

                <section class="project-backup-manager">

                    <header class="project-backup-header">
                        <div>
                            <p class="eyebrow">BACKUP MANAGER</p>
                            <h2>Recovery Points</h2>
                            <p class="project-backup-description">
                                Create and restore backups for ${this.escapeHTML(this.getProjectTitle(project))}.
                            </p>
                        </div>

                        <div class="project-backup-header-actions">
                            <button
                                type="button"
                                class="button button-primary"
                                data-action="create-backup"
                            >
                                Create Backup
                            </button>
                        </div>
                    </header>


                    <div class="project-backup-meta-grid">
                        <article class="project-backup-meta-card">
                            <h3>Backup Count</h3>
                            <p>${backups.length}</p>
                        </article>

                        <article class="project-backup-meta-card">
                            <h3>Last Backup</h3>
                            <p>${latestBackup ? this.escapeHTML(this.formatProjectDate(latestBackup.createdAt)) : "No backups yet"}</p>
                        </article>
                    </div>


                    ${
                        backups.length > 0
                            ? `
                                <ul class="project-backup-list" aria-label="Project backups">
                                    ${backups
                                        .map(
                                            backup => `
                                                <li class="project-backup-item">
                                                    <div class="project-backup-item-main">
                                                        <h3>${this.escapeHTML(this.formatBackupType(backup.type))}</h3>
                                                        <p>
                                                            ${this.escapeHTML(this.formatProjectDate(backup.createdAt))}
                                                            •
                                                            ${this.escapeHTML(backup.projectName || this.getProjectTitle(project))}
                                                        </p>
                                                        <p class="project-backup-item-meta">
                                                            Backup ID: ${this.escapeHTML(backup.id)}
                                                        </p>
                                                    </div>

                                                    <div class="project-backup-item-actions">
                                                        <button
                                                            type="button"
                                                            class="button button-secondary"
                                                            data-action="restore-backup"
                                                            data-backup-id="${this.escapeHTML(backup.id)}"
                                                        >
                                                            Restore
                                                        </button>

                                                        <button
                                                            type="button"
                                                            class="button button-danger"
                                                            data-action="delete-backup"
                                                            data-backup-id="${this.escapeHTML(backup.id)}"
                                                        >
                                                            Delete Backup
                                                        </button>
                                                    </div>
                                                </li>
                                            `
                                        )
                                        .join("")}
                                </ul>
                            `
                            : `
                                <section class="project-backup-empty-state">
                                    <h3>No backups yet.</h3>
                                    <p>Create a backup to protect this project before major changes.</p>
                                    <button
                                        type="button"
                                        class="button button-primary"
                                        data-action="create-backup"
                                    >
                                        Create First Backup
                                    </button>
                                </section>
                            `
                    }

                </section>

            `;

        },


        getProjectBackups(projectId) {

            const backups =
                this.core.storage.loadProjectBackups(
                    projectId
                );


            return backups
                .filter(
                    backup =>
                        this.isValidBackupRecord(
                            backup
                        )
                )
                .sort(
                    (left, right) => {

                        const leftTime =
                            new Date(
                                left.createdAt
                            ).getTime();

                        const rightTime =
                            new Date(
                                right.createdAt
                            ).getTime();


                        return rightTime - leftTime;

                    }
                );

        },


        getProjectSummaryItems(project) {

            const items = [];


            items.push({
                label: "Title",
                value: this.getProjectTitle(project)
            });


            if (
                typeof project.status === "string" &&
                project.status.trim()
            ) {

                items.push({
                    label: "Status",
                    value: project.status.trim()
                });

            }


            if (
                typeof project.type === "string" &&
                project.type.trim()
            ) {

                items.push({
                    label: "Type",
                    value: project.type.trim()
                });

            }


            if (
                this.getProjectGenreTags(
                    project
                ).length
            ) {

                items.push({
                    label: "Genres",
                    value: this.getProjectGenreLabel(
                        project
                    )
                });

            }


            if (
                typeof project.author === "string" &&
                project.author.trim()
            ) {

                items.push({
                    label: "Author",
                    value: project.author.trim()
                });

            }


            const created =
                this.formatProjectDate(
                    project.createdAt
                );


            if (created !== "Unavailable") {

                items.push({
                    label: "Created",
                    value: created
                });

            }


            const modified =
                this.formatProjectDate(
                    project.lastModified ||
                    project.updatedAt
                );


            if (modified !== "Unavailable") {

                items.push({
                    label: "Last Modified",
                    value: modified
                });

            }


            const targetWords =
                Number(
                    project.targetWords
                );


            const backups =
                this.getProjectBackups(
                    project.id
                );


            if (
                Number.isFinite(
                    targetWords
                ) &&
                targetWords > 0
            ) {

                items.push({
                    label: "Target Words",
                    value: `${targetWords.toLocaleString()} words`
                });

            }


            if (
                this.hasWordCountSignal(
                    project
                )
            ) {

                items.push({
                    label: "Current Words",
                    value: `${this.getProjectWordCount(project).toLocaleString()} words`
                });

            }


            const characterRecords =
                Array.isArray(
                    project?.story?.characters
                )
                    ? project.story.characters
                    : [];

            if (characterRecords.length > 0) {

                items.push({
                    label: "Characters",
                    value: `${characterRecords.filter(character => String(character?.status || "") !== "Archived").length} active / ${characterRecords.length} total`
                });

            }


            const worldRecords =
                Array.isArray(
                    project?.story?.worldEntries
                )
                    ? project.story.worldEntries
                    : [];

            if (worldRecords.length > 0) {

                items.push({
                    label: "World Entries",
                    value: `${worldRecords.filter(entry => String(entry?.status || "") !== "Archived").length} active / ${worldRecords.length} total`
                });

            }


            const plot =
                project?.story?.plot && typeof project.story.plot === "object"
                    ? project.story.plot
                    : null;

            const plotArcs =
                Array.isArray(plot?.arcs)
                    ? plot.arcs
                    : [];

            const plotScenes =
                Array.isArray(plot?.scenes)
                    ? plot.scenes
                    : [];

            if (plotArcs.length > 0 || plotScenes.length > 0) {

                items.push({
                    label: "Plot",
                    value: `${plotArcs.length} arcs | ${plotScenes.filter(scene => String(scene?.status || "") === "Complete").length}/${plotScenes.length} scenes complete`
                });

            }


            const timeline =
                project?.story?.timeline &&
                typeof project.story.timeline === "object" &&
                !Array.isArray(project.story.timeline)
                    ? project.story.timeline
                    : null;

            const timelineEvents =
                Array.isArray(timeline?.events)
                    ? timeline.events
                    : [];

            const timelineEras =
                Array.isArray(timeline?.eras)
                    ? timeline.eras
                    : [];

            if (timelineEvents.length > 0 || timelineEras.length > 0) {

                items.push({
                    label: "Timeline",
                    value: `${timelineEvents.length} events | ${timelineEras.length} eras`
                });

            }


            const notesStudio =
                project?.story?.notesStudio &&
                typeof project.story.notesStudio === "object"
                    ? project.story.notesStudio
                    : null;

            const notesRecords =
                Array.isArray(notesStudio?.records)
                    ? notesStudio.records
                    : [];

            const notesSources =
                Array.isArray(notesStudio?.sources)
                    ? notesStudio.sources
                    : [];

            if (notesRecords.length > 0 || notesSources.length > 0) {

                items.push({
                    label: "Notes & Research",
                    value: `${notesRecords.filter(record => String(record?.type || "") === "Note").length} notes | ${notesRecords.filter(record => String(record?.type || "") === "Research").length} research | ${notesSources.length} sources`
                });

            }


            items.push({
                label: "Backups",
                value: `${backups.length}`
            });


            if (
                backups.length > 0
            ) {

                items.push({
                    label: "Last Backup",
                    value: this.formatProjectDate(
                        backups[0].createdAt
                    )
                });

            }


            return items;

        },


        renderProjectDescription(project) {

            const description =
                typeof project.description === "string"
                    ? project.description.trim()
                    : "";


            if (!description) {

                return `
                    <section class="project-dashboard-description-empty">
                        <h3>Description</h3>
                        <p>No project description has been added yet.</p>
                    </section>
                `;

            }


            return `
                <section class="project-dashboard-description">
                    <h3>Description</h3>
                    <p>${this.escapeHTML(description)}</p>
                </section>
            `;

        },


        renderWritingProgress(project) {

            const currentWords =
                this.getProjectWordCount(project);


            const chapterCount =
                this.getChapterCount(project);


            const hasContent =
                currentWords > 0 ||
                chapterCount > 0;


            if (!hasContent) {

                return `
                    <div class="project-dashboard-empty-state">
                        <h3>Your story starts here.</h3>
                        <p>No manuscript content yet. Begin writing to track progress.</p>
                    </div>
                `;

            }


            const targetWords =
                Number(
                    project.targetWords
                );


            if (
                Number.isFinite(
                    targetWords
                ) &&
                targetWords > 0
            ) {

                const progress =
                    Math.min(
                        100,
                        Math.round(
                            (currentWords / targetWords) * 100
                        )
                    );


                return `
                    <div class="project-dashboard-progress-block">
                        <p class="project-dashboard-progress-numbers">
                            ${currentWords.toLocaleString()} / ${targetWords.toLocaleString()} words
                        </p>
                        <progress
                            class="project-dashboard-progress-native"
                            value="${currentWords}"
                            max="${targetWords}"
                        ></progress>
                        <p class="project-dashboard-progress-percent">${progress}% complete</p>
                    </div>
                `;

            }


            return `
                <div class="project-dashboard-progress-block">
                    <p class="project-dashboard-progress-numbers">
                        ${currentWords.toLocaleString()} words tracked
                    </p>
                    <p class="project-dashboard-progress-percent">Set a target word count to track completion.</p>
                </div>
            `;

        },


        renderProjectStatistics(project) {

            const stats =
                this.getProjectStatistics(project);


            if (stats.length === 0) {

                return `
                    <div class="project-dashboard-empty-state">
                        <h3>Statistics will appear as you build.</h3>
                        <p>Add manuscript and story data to unlock project statistics.</p>
                    </div>
                `;

            }


            return `
                <div class="project-dashboard-stats-grid">
                    ${stats
                        .map(
                            stat => `
                                <article class="project-dashboard-stat-card">
                                    <h3>${this.escapeHTML(stat.label)}</h3>
                                    <p>${this.escapeHTML(stat.value)}</p>
                                </article>
                            `
                        )
                        .join("")}
                </div>
            `;

        },


        getProjectStatistics(project) {

            const stats = [];


            const wordCount =
                this.getProjectWordCount(project);


            if (wordCount > 0) {

                stats.push({
                    label: "Word Count",
                    value: `${wordCount.toLocaleString()} words`
                });

            }


            const chapterCount =
                this.getChapterCount(project);


            if (chapterCount > 0) {

                stats.push({
                    label: "Chapters",
                    value: `${chapterCount}`
                });

            }


            const sceneCount =
                Number(
                    project?.statistics?.scenes
                );


            if (
                Number.isFinite(
                    sceneCount
                ) &&
                sceneCount > 0
            ) {

                stats.push({
                    label: "Scenes",
                    value: `${sceneCount}`
                });

            }


            const characterCount =
                Array.isArray(
                    project?.story?.characters
                )
                    ? project.story.characters.length
                    : 0;


            if (characterCount > 0) {

                stats.push({
                    label: "Characters",
                    value: `${characterCount}`
                });

            }


            const worldEntryCount =
                Array.isArray(
                    project?.story?.worldEntries
                )
                    ? project.story.worldEntries.length
                    : 0;


            if (worldEntryCount > 0) {

                stats.push({
                    label: "World Entries",
                    value: `${worldEntryCount}`
                });

            }


            const plotArcsCount =
                Array.isArray(
                    project?.story?.plot?.arcs
                )
                    ? project.story.plot.arcs.length
                    : 0;

            const plotScenesCount =
                Array.isArray(
                    project?.story?.plot?.scenes
                )
                    ? project.story.plot.scenes.length
                    : 0;

            const plotCompleteScenes =
                Array.isArray(
                    project?.story?.plot?.scenes
                )
                    ? project.story.plot.scenes.filter(
                        scene => String(scene?.status || "") === "Complete"
                    ).length
                    : 0;


            if (plotArcsCount > 0 || plotScenesCount > 0) {

                stats.push({
                    label: "Plot Arcs",
                    value: `${plotArcsCount}`
                });

                stats.push({
                    label: "Plot Scenes",
                    value: `${plotCompleteScenes}/${plotScenesCount} complete`
                });

            }


            const timelineEventsCount =
                Array.isArray(
                    project?.story?.timeline?.events
                )
                    ? project.story.timeline.events.length
                    : 0;

            const timelineCompletedEvents =
                Array.isArray(
                    project?.story?.timeline?.events
                )
                    ? project.story.timeline.events.filter(
                        event => String(event?.status || "") === "Completed"
                    ).length
                    : 0;

            const timelineErasCount =
                Array.isArray(
                    project?.story?.timeline?.eras
                )
                    ? project.story.timeline.eras.length
                    : 0;

            if (timelineEventsCount > 0 || timelineErasCount > 0) {

                stats.push({
                    label: "Timeline Events",
                    value: `${timelineCompletedEvents}/${timelineEventsCount} complete`
                });

                stats.push({
                    label: "Timeline Eras",
                    value: `${timelineErasCount}`
                });

            }


            const notesCount =
                Array.isArray(
                    project?.story?.notes
                )
                    ? project.story.notes.length
                    : 0;

            const notesStudioRecords =
                Array.isArray(
                    project?.story?.notesStudio?.records
                )
                    ? project.story.notesStudio.records
                    : [];

            const notesStudioSourcesCount =
                Array.isArray(
                    project?.story?.notesStudio?.sources
                )
                    ? project.story.notesStudio.sources.length
                    : 0;


            if (notesCount > 0) {

                stats.push({
                    label: "Notes",
                    value: `${notesCount}`
                });

            }


            if (notesStudioRecords.length > 0 || notesStudioSourcesCount > 0) {

                stats.push({
                    label: "Research Notes",
                    value: `${notesStudioRecords.filter(record => String(record?.type || "") === "Note").length}`
                });

                stats.push({
                    label: "Research Entries",
                    value: `${notesStudioRecords.filter(record => String(record?.type || "") === "Research").length}`
                });

                stats.push({
                    label: "Sources",
                    value: `${notesStudioSourcesCount}`
                });

            }


            const projectAge =
                this.getProjectAgeDays(
                    project
                );


            if (projectAge !== null) {

                stats.push({
                    label: "Project Age",
                    value:
                        projectAge === 0
                            ? "Today"
                            : `${projectAge} day${projectAge === 1 ? "" : "s"}`
                });

            }


            const lastActivity =
                this.formatProjectDate(
                    project.lastOpened ||
                    project.lastModified ||
                    project.updatedAt
                );


            if (lastActivity !== "Unavailable") {

                stats.push({
                    label: "Last Activity",
                    value: lastActivity
                });

            }


            return stats;

        },


        renderRecentActivity(project) {

            const activity =
                this.getRecentProjectActivity(
                    project
                );


            if (activity.length === 0) {

                return `
                    <div class="project-dashboard-empty-state">
                        <h3>No activity recorded yet.</h3>
                        <p>Project activity will appear here as you continue working.</p>
                    </div>
                `;

            }


            return `
                <ul class="project-dashboard-activity-list">
                    ${activity
                        .map(
                            item => `
                                <li>
                                    <span class="project-dashboard-activity-label">${this.escapeHTML(item.label)}</span>
                                    <time datetime="${this.escapeHTML(item.iso)}">${this.escapeHTML(item.time)}</time>
                                </li>
                            `
                        )
                        .join("")}
                </ul>
            `;

        },


        getRecentProjectActivity(project) {

            const entries = [];


            const pushEntry = (
                label,
                value
            ) => {

                if (!value) {

                    return;

                }


                const date =
                    new Date(value);


                if (
                    Number.isNaN(
                        date.getTime()
                    )
                ) {

                    return;

                }


                entries.push({
                    label,
                    iso: date.toISOString(),
                    time: date.toLocaleString(),
                    timestamp: date.getTime()
                });

            };


            pushEntry(
                "Project created",
                project.createdAt
            );

            pushEntry(
                "Project opened",
                project.lastOpened
            );

            pushEntry(
                "Project updated",
                project.lastModified ||
                project.updatedAt
            );


            return entries
                .sort(
                    (a, b) =>
                        b.timestamp -
                        a.timestamp
                )
                .slice(0, 5);

        },


        hasWordCountSignal(project) {

            return Number.isFinite(
                Number(
                    project?.statistics?.words
                )
            ) || Number.isFinite(
                Number(
                    project?.wordCount
                )
            );

        },


        getChapterCount(project) {

            const chapters =
                Array.isArray(
                    project?.manuscript?.chapters
                )
                    ? project.manuscript.chapters.length
                    : 0;


            if (chapters > 0) {

                return chapters;

            }


            const fromStatistics =
                Number(
                    project?.statistics?.chapters
                );


            return Number.isFinite(
                fromStatistics
            )
                ? Math.max(
                    0,
                    fromStatistics
                )
                : 0;

        },


        getProjectAgeDays(project) {

            const createdAt =
                project?.createdAt;


            if (!createdAt) {

                return null;

            }


            const created =
                new Date(createdAt);


            if (
                Number.isNaN(
                    created.getTime()
                )
            ) {

                return null;

            }


            const now =
                Date.now();


            const delta =
                Math.max(
                    0,
                    now - created.getTime()
                );


            return Math.floor(
                delta /
                86400000
            );

        },


        renderProjectWorkspaceEmptyState() {

            return `

                <section class="project-workspace-empty">
                    <div class="empty-view-icon">◇</div>
                    <h1>No active project</h1>
                    <p>Open a story from the Story Library to enter the project workspace.</p>
                    <button
                        type="button"
                        class="button button-primary"
                        data-action="return-to-library"
                    >
                        Return to Story Library
                    </button>
                </section>

            `;

        },


        bindProjectWorkspaceEvents(
            container,
            projectId
        ) {

            container
                .querySelectorAll(
                    '[data-action="return-to-library"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            if (
                                this.core.autosave?.dirty
                            ) {

                                this.core.autosave.flush({
                                    reason:
                                        "return-to-library"
                                });

                            }

                            this.core.navigation.navigate(
                                "projects"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="continue-manuscript"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "manuscript"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="open-character-studio"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "characters"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="open-world-studio"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "world"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="open-plot-studio"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "plot"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="open-timeline-studio"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "timeline"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="open-notes-studio"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "notes"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="project-settings"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.core.navigation.navigate(
                                "settings"
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="open-backup-manager"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.projectWorkspaceSection =
                                "backups";

                            this.renderProjectWorkspace(
                                this.container
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="edit-project-details"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            if (!projectId) {

                                this.core.notify(
                                    "No active project is available.",
                                    "error"
                                );

                                return;

                            }


                            this.showEditProjectModal(
                                projectId
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="delete-project-details"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            if (!projectId) {

                                this.core.notify(
                                    "No active project is available.",
                                    "error"
                                );

                                return;

                            }


                            this.showDeleteProjectModal(
                                projectId
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="create-backup"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.createProjectBackup(
                                projectId,
                                {
                                    type:
                                        "manual",
                                    reason:
                                        "Manual Backup"
                                }
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="restore-backup"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.showRestoreBackupModal(
                                button.dataset.backupId,
                                projectId
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    '[data-action="delete-backup"]'
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            this.showDeleteBackupModal(
                                button.dataset.backupId,
                                projectId
                            );

                        }
                    );

                });


            container
                .querySelectorAll(
                    "[data-workspace-section]"
                )
                .forEach(button => {

                    button.addEventListener(
                        "click",
                        event => {

                            event.preventDefault();

                            const nextSection =
                                button.dataset.workspaceSection;


                            if (!nextSection) {

                                return;

                            }


                            if (
                                nextSection ===
                                "manuscript"
                            ) {

                                this.core.navigation.navigate(
                                    "manuscript"
                                );

                                return;

                            }


                            if (
                                nextSection ===
                                "characters"
                            ) {

                                this.core.navigation.navigate(
                                    "characters"
                                );

                                return;

                            }


                            if (
                                nextSection ===
                                "world"
                            ) {

                                this.core.navigation.navigate(
                                    "world"
                                );

                                return;

                            }


                            if (
                                nextSection ===
                                "plot"
                            ) {

                                this.core.navigation.navigate(
                                    "plot"
                                );

                                return;

                            }


                            if (
                                nextSection ===
                                "timeline"
                            ) {

                                this.core.navigation.navigate(
                                    "timeline"
                                );

                                return;

                            }


                            if (
                                nextSection ===
                                "notes"
                            ) {

                                this.core.navigation.navigate(
                                    "notes"
                                );

                                return;

                            }


                            this.projectWorkspaceSection =
                                nextSection;


                            if (!projectId) {

                                this.renderProjectWorkspace(
                                    this.container
                                );

                                return;

                            }


                            const latestProject =
                                this.getProject(
                                    projectId
                                );


                            if (!latestProject) {

                                this.core.notify(
                                    "Active project could not be found.",
                                    "error"
                                );

                            }


                            this.renderProjectWorkspace(
                                this.container
                            );

                        }
                    );

                });

        },


        formatProjectDate(value) {

            if (!value) {

                return "Unavailable";

            }


            const date =
                new Date(value);


            if (
                Number.isNaN(
                    date.getTime()
                )
            ) {

                return "Unavailable";

            }


            return date.toLocaleString();

        },


        getProjectWordCount(project) {

            const fromStatistics =
                Number(
                    project?.statistics?.words
                );


            if (
                Number.isFinite(
                    fromStatistics
                )
            ) {

                return Math.max(
                    0,
                    fromStatistics
                );

            }


            const fromModelWordCount =
                Number(
                    project?.wordCount
                );


            if (
                Number.isFinite(
                    fromModelWordCount
                )
            ) {

                return Math.max(
                    0,
                    fromModelWordCount
                );

            }


            return 0;

        },


        /*
        =====================================================
        FILTER CONTROLS
        =====================================================
        */

        renderLibraryControls() {

            const genres =
                this.getUniqueGenreTags();


            const types =
                this.getUniqueValues(
                    "type"
                );


            const statuses =
                this.getUniqueValues(
                    "status"
                );


            return `

                <div class="library-controls">

                    <div class="library-search">

                        <label
                            for="library-search-input"
                            class="visually-hidden"
                        >
                            Search projects
                        </label>

                        <span
                            class="library-search-icon"
                            aria-hidden="true"
                        >
                            ⌕
                        </span>

                        <input
                            id="library-search-input"
                            type="search"
                            class="library-search-input"
                            placeholder="Search your stories..."
                            autocomplete="off"
                            value="${this.escapeHTML(
                                this.libraryFilters.search
                            )}"
                        />

                        ${
                            this.libraryFilters.search
                                ? `
                                    <button
                                        type="button"
                                        class="library-search-clear"
                                        data-action="clear-search"
                                        aria-label="Clear search"
                                    >
                                        ×
                                    </button>
                                `
                                : ""
                        }

                    </div>


                    <div class="library-filter-group">

                        <label
                            for="library-status-filter"
                        >
                            Status
                        </label>

                        <select
                            id="library-status-filter"
                            class="library-filter-select"
                        >

                            <option
                                value="all"
                                ${
                                    this.libraryFilters.status === "all"
                                        ? "selected"
                                        : ""
                                }
                            >
                                All statuses
                            </option>

                            ${
                                statuses
                                    .map(
                                        status => `
                                            <option
                                                value="${this.escapeHTML(
                                                    status
                                                )}"
                                                ${
                                                    this.libraryFilters.status === status
                                                        ? "selected"
                                                        : ""
                                                }
                                            >
                                                ${this.escapeHTML(
                                                    status
                                                )}
                                            </option>
                                        `
                                    )
                                    .join("")
                            }

                        </select>

                    </div>


                    <div class="library-filter-group">

                        <label
                            for="library-genre-filter"
                        >
                            Genre
                        </label>

                        <select
                            id="library-genre-filter"
                            class="library-filter-select"
                        >

                            <option
                                value="all"
                                ${
                                    this.libraryFilters.genre === "all"
                                        ? "selected"
                                        : ""
                                }
                            >
                                All genres
                            </option>

                            ${
                                genres
                                    .map(
                                        genre => `
                                            <option
                                                value="${this.escapeHTML(
                                                    genre
                                                )}"
                                                ${
                                                    this.libraryFilters.genre === genre
                                                        ? "selected"
                                                        : ""
                                                }
                                            >
                                                ${this.escapeHTML(
                                                    genre
                                                )}
                                            </option>
                                        `
                                    )
                                    .join("")
                            }

                        </select>

                    </div>


                    <div class="library-filter-group">

                        <label
                            for="library-type-filter"
                        >
                            Type
                        </label>

                        <select
                            id="library-type-filter"
                            class="library-filter-select"
                        >

                            <option
                                value="all"
                                ${
                                    this.libraryFilters.type === "all"
                                        ? "selected"
                                        : ""
                                }
                            >
                                All types
                            </option>

                            ${
                                types
                                    .map(
                                        type => `
                                            <option
                                                value="${this.escapeHTML(
                                                    type
                                                )}"
                                                ${
                                                    this.libraryFilters.type === type
                                                        ? "selected"
                                                        : ""
                                                }
                                            >
                                                ${this.escapeHTML(
                                                    type
                                                )}
                                            </option>
                                        `
                                    )
                                    .join("")
                            }

                        </select>

                    </div>


                    <div class="library-filter-group">

                        <label
                            for="library-sort-filter"
                        >
                            Sort
                        </label>

                        <select
                            id="library-sort-filter"
                            class="library-filter-select"
                        >

                            <option
                                value="updated"
                                ${
                                    this.libraryFilters.sort === "updated"
                                        ? "selected"
                                        : ""
                                }
                            >
                                Recently updated
                            </option>

                            <option
                                value="opened"
                                ${
                                    this.libraryFilters.sort === "opened"
                                        ? "selected"
                                        : ""
                                }
                            >
                                Recently opened
                            </option>

                            <option
                                value="created"
                                ${
                                    this.libraryFilters.sort === "created"
                                        ? "selected"
                                        : ""
                                }
                            >
                                Recently created
                            </option>

                            <option
                                value="title-asc"
                                ${
                                    this.libraryFilters.sort === "title-asc"
                                        ? "selected"
                                        : ""
                                }
                            >
                                Title A–Z
                            </option>

                            <option
                                value="title-desc"
                                ${
                                    this.libraryFilters.sort === "title-desc"
                                        ? "selected"
                                        : ""
                                }
                            >
                                Title Z–A
                            </option>

                            <option
                                value="words"
                                ${
                                    this.libraryFilters.sort === "words"
                                        ? "selected"
                                        : ""
                                }
                            >
                                Word count
                            </option>

                        </select>

                    </div>


                    <label class="library-archive-toggle">

                        <input
                            id="library-archived-toggle"
                            type="checkbox"
                            ${
                                this.libraryFilters.showArchived
                                    ? "checked"
                                    : ""
                            }
                        />

                        <span>
                            Show archived
                        </span>

                    </label>


                    ${
                        this.hasActiveFilters()
                            ? `
                                <button
                                    type="button"
                                    class="library-clear-filters"
                                    data-action="clear-filters"
                                >
                                    Clear filters
                                </button>
                            `
                            : ""
                    }

                </div>

            `;

        },


        /*
        =====================================================
        UNIQUE FILTER VALUES
        =====================================================
        */

        getUniqueValues(field) {

            const values =
                this.getProjects()
                    .map(
                        project =>
                            String(
                                project?.[field] ||
                                ""
                            ).trim()
                    )
                    .filter(
                        value =>
                            value.length > 0
                    );


            return [
                ...new Set(
                    values
                )
            ].sort(
                (a, b) =>
                    a.localeCompare(
                        b,
                        undefined,
                        {
                            sensitivity:
                                "base"
                        }
                    )
            );

        },


        /*
        =====================================================
        FILTER PROJECTS
        =====================================================
        */

        getFilteredProjects(projects) {

            let results =
                Array.isArray(projects)
                    ? [...projects]
                    : [];


            if (
                !this.libraryFilters.showArchived
            ) {

                results =
                    results.filter(
                        project =>
                            project.status !==
                            "Archived"
                    );

            }


            if (
                this.libraryFilters.status !==
                "all"
            ) {

                results =
                    results.filter(
                        project =>
                            String(
                                project.status ||
                                ""
                            ) ===
                            this.libraryFilters.status
                    );

            }


            if (
                this.libraryFilters.genre !==
                "all"
            ) {

                results =
                    results.filter(
                        project => {

                            const tags =
                                this.getProjectGenreTags(
                                    project
                                );

                            return tags.includes(
                                this.libraryFilters.genre
                            );

                        }
                    );

            }


            if (
                this.libraryFilters.type !==
                "all"
            ) {

                results =
                    results.filter(
                        project =>
                            String(
                                project.type ||
                                ""
                            ) ===
                            this.libraryFilters.type
                    );

            }


            const search =
                this.libraryFilters.search
                    .trim()
                    .toLowerCase();


            if (search) {

                results =
                    results.filter(
                        project => {

                            const searchableText =
                                [

                                    project.name,

                                    project.title,

                                    project.author,

                                    ...this.getProjectGenreTags(
                                        project
                                    ),

                                    project.type,

                                    project.status,

                                    project.series,

                                    project.description

                                ]
                                    .filter(
                                        value =>
                                            value !==
                                            null &&
                                            value !==
                                            undefined
                                    )
                                    .join(" ")
                                    .toLowerCase();


                            return searchableText
                                .includes(
                                    search
                                );

                        }
                    );

            }


            return this.sortProjects(
                results
            );

        },


        /*
        =====================================================
        SORT PROJECTS
        =====================================================
        */

        sortProjects(projects) {

            const results =
                [...projects];


            const getDate =
                value => {

                    const time =
                        Date.parse(
                            value ||
                            ""
                        );


                    return Number.isNaN(
                        time
                    )
                        ? 0
                        : time;

                };


            const getWords =
                project =>
                    Number(
                        project?.statistics?.words ||
                        0
                    );


            switch (
                this.libraryFilters.sort
            ) {

                case "opened":

                    return results.sort(
                        (a, b) =>
                            getDate(
                                b.lastOpened
                            ) -
                            getDate(
                                a.lastOpened
                            )
                    );


                case "created":

                    return results.sort(
                        (a, b) =>
                            getDate(
                                b.createdAt
                            ) -
                            getDate(
                                a.createdAt
                            )
                    );


                case "title-asc":

                    return results.sort(
                        (a, b) =>
                            this.getProjectTitle(
                                a
                            ).localeCompare(
                                this.getProjectTitle(
                                    b
                                ),
                                undefined,
                                {
                                    sensitivity:
                                        "base"
                                }
                            )
                    );


                case "title-desc":

                    return results.sort(
                        (a, b) =>
                            this.getProjectTitle(
                                b
                            ).localeCompare(
                                this.getProjectTitle(
                                    a
                                ),
                                undefined,
                                {
                                    sensitivity:
                                        "base"
                                }
                            )
                    );


                case "words":

                    return results.sort(
                        (a, b) =>
                            getWords(b) -
                            getWords(a)
                    );


                case "updated":

                default:

                    return results.sort(
                        (a, b) =>
                            getDate(
                                b.updatedAt ||
                                b.lastModified ||
                                b.createdAt
                            ) -
                            getDate(
                                a.updatedAt ||
                                a.lastModified ||
                                a.createdAt
                            )
                    );

            }

        },


        /*
        =====================================================
        PROJECT TITLE
        =====================================================
        */

        getProjectTitle(project) {

            return String(
                project?.name ||
                project?.title ||
                "Untitled Project"
            ).trim();

        },


        /*
        =====================================================
        ACTIVE FILTERS
        =====================================================
        */

        hasActiveFilters() {

            return Boolean(

                this.libraryFilters.search ||

                this.libraryFilters.status !==
                "all" ||

                this.libraryFilters.genre !==
                "all" ||

                this.libraryFilters.type !==
                "all" ||

                this.libraryFilters.sort !==
                "updated" ||

                !this.libraryFilters.showArchived

            );

        },


        /*
        =====================================================
        CLEAR FILTERS
        =====================================================
        */

        clearFilters() {

            this.libraryFilters = {

                search: "",

                status: "all",

                genre: "all",

                type: "all",

                sort: "updated",

                showArchived: true

            };


            this.render(
                this.container
            );

        },


        /*
        =====================================================
        PROJECT GRID
        =====================================================
        */

        renderProjectGrid(projects) {

            return `

                <div class="project-grid">

                    ${projects
                        .map(
                            project =>
                                this.renderProjectCard(
                                    project
                                )
                        )
                        .join("")}

                </div>

            `;

        },


        /*
        =====================================================
        NO RESULTS
        =====================================================
        */

        renderNoResultsState() {

            const hasProjects =
                this.getProjects().length >
                0;


            return `

                <section
                    class="library-empty-state
                           library-no-results"
                >

                    <div class="empty-state-icon">
                        ⌕
                    </div>

                    <h2>

                        ${
                            hasProjects
                                ? "No stories found"
                                : "Your library is empty"
                        }

                    </h2>

                    <p>

                        ${
                            hasProjects
                                ? "Try changing your search or filters."
                                : "Create your first story to begin building your Author Studio library."
                        }

                    </p>


                    ${
                        hasProjects &&
                        this.hasActiveFilters()
                            ? `
                                <button
                                    type="button"
                                    class="button button-secondary"
                                    data-action="clear-filters"
                                >
                                    Clear Filters
                                </button>
                            `
                            : `
                                <button
                                    type="button"
                                    class="button button-primary"
                                    data-action="new-project"
                                >
                                    + Create Your First Project
                                </button>
                            `
                    }

                </section>

            `;

        },


        /*
        =====================================================
        PROJECT CARD
        =====================================================
        */

        renderProjectCard(project) {

            const title =
                this.escapeHTML(
                    project.name ||
                    project.title ||
                    "Untitled Project"
                );


            const author =
                this.escapeHTML(
                    project.author ||
                    "Unknown Author"
                );


            const genre =
                this.escapeHTML(
                    this.getProjectGenreLabel(
                        project
                    )
                );


            const genreTags =
                this.getProjectGenreTags(
                    project
                );


            const genreTagChips =
                genreTags
                    .map(
                        (tag, index) => `
                            <span
                                class="project-genre-chip ${this.getGenreTagFamilyClass(tag)} ${index === 0 ? "project-genre-chip-primary" : ""}"
                            >
                                ${this.escapeHTML(tag)}
                            </span>
                        `
                    )
                    .join("");


            const series =
                this.escapeHTML(
                    project.series ||
                    "Standalone"
                );


            const status =
                this.escapeHTML(
                    project.status ||
                    "Draft"
                );


            const words =
                Number(
                    project.statistics?.words ||
                    0
                ).toLocaleString();


            const projectId =
                this.escapeHTML(
                    project.id
                );


            const archived =
                project.status ===
                "Archived";


            const projectImage =
                this.normalizeProjectImageAsset(
                    project.image
                );

            const hasProjectImage =
                Boolean(
                    projectImage?.dataUrl
                );

            const projectImageAlt =
                `${title} cover image`;


            return `

                <article
                    class="
                        project-card
                        ${archived ? "project-card-archived" : ""}
                    "
                    data-project-id="${projectId}"
                >

                    <div
                        class="project-card-cover-button"
                        role="button"
                        tabindex="0"
                        data-action="open-project"
                        data-project-id="${projectId}"
                        aria-label="Open ${title}"
                    >

                        <div class="project-cover">

                            ${hasProjectImage
                                ? `
                                    <img
                                        class="project-cover-image"
                                        src="${this.escapeHTML(projectImage.dataUrl)}"
                                        alt="${this.escapeHTML(projectImageAlt)}"
                                        loading="lazy"
                                        decoding="async"
                                    >
                                    <span class="project-cover-image-overlay" aria-hidden="true"></span>
                                    <span class="project-cover-image-label">
                                        ${genre}
                                    </span>
                                `
                                : `
                                    <div class="project-cover-inner">

                                        <span class="project-cover-genre">
                                            ${genre}
                                        </span>

                                        <h2>
                                            ${title}
                                        </h2>

                                        <span class="project-cover-series">
                                            ${series}
                                        </span>

                                    </div>
                                `
                            }

                        </div>

                    </div>


                    <div class="project-card-body">

                        <div class="project-card-title-row">

                            <button
                                type="button"
                                class="project-title-button"
                                data-action="open-project"
                                data-project-id="${projectId}"
                            >

                                <span>
                                    ${title}
                                </span>

                            </button>


                            <span
                                class="
                                    project-status
                                    ${archived ? "project-status-archived" : ""}
                                "
                            >
                                ${status}
                            </span>

                        </div>


                        <div class="project-card-meta">

                            <span>
                                ${author}
                            </span>

                            <span>
                                ${words} words
                            </span>

                        </div>


                        <div
                            class="project-card-tags"
                            aria-label="Project genre tags"
                        >
                            ${genreTagChips}
                        </div>


                        <div class="project-card-actions">

                            <button
                                type="button"
                                class="project-card-action"
                                data-action="edit-project"
                                data-project-id="${projectId}"
                            >
                                Edit
                            </button>


                            <button
                                type="button"
                                class="project-card-action"
                                data-action="${
                                    archived
                                        ? "unarchive-project"
                                        : "archive-project"
                                }"
                                data-project-id="${projectId}"
                            >

                                ${
                                    archived
                                        ? "Unarchive"
                                        : "Archive"
                                }

                            </button>


                            <button
                                type="button"
                                class="
                                    project-card-action
                                    project-card-action-danger
                                "
                                data-action="delete-project"
                                data-project-id="${projectId}"
                            >
                                Delete
                            </button>

                        </div>

                    </div>

                </article>

            `;

        },


        /*
        =====================================================
        EMPTY STATE
        =====================================================
        */

        renderEmptyState() {

            return this.renderNoResultsState();

        },


        /*
        =====================================================
        LIBRARY EVENTS
        =====================================================
        */

        bindLibraryEvents(container) {

            container
                .querySelectorAll(
                    '[data-action="new-project"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.showCreateProjectModal();

                            }
                        );

                    }
                );


            container
                .querySelectorAll(
                    '[data-action="clear-filters"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.clearFilters();

                            }
                        );

                    }
                );


            container
                .querySelectorAll(
                    '[data-action="open-project"]'
                )
                .forEach(
                    element => {

                        element.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.openProject(
                                    element.dataset.projectId
                                );

                            }
                        );


                        element.addEventListener(
                            "keydown",
                            event => {

                                if (
                                    event.key ===
                                    "Enter" ||
                                    event.key ===
                                    " "
                                ) {

                                    event.preventDefault();

                                    this.openProject(
                                        element.dataset.projectId
                                    );

                                }

                            }
                        );

                    }
                );


            container
                .querySelectorAll(
                    '[data-action="edit-project"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.showEditProjectModal(
                                    button.dataset.projectId
                                );

                            }
                        );

                    }
                );


            container
                .querySelectorAll(
                    '[data-action="archive-project"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.archiveProject(
                                    button.dataset.projectId
                                );

                            }
                        );

                    }
                );


            container
                .querySelectorAll(
                    '[data-action="unarchive-project"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.unarchiveProject(
                                    button.dataset.projectId
                                );

                            }
                        );

                    }
                );


            container
                .querySelectorAll(
                    '[data-action="delete-project"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.showDeleteProjectModal(
                                    button.dataset.projectId
                                );

                            }
                        );

                    }
                );

        },


        /*
        =====================================================
        FILTER EVENTS
        =====================================================
        */

        bindFilterEvents(container) {

            const searchInput =
                container.querySelector(
                    "#library-search-input"
                );


            if (searchInput) {

                searchInput.addEventListener(
                    "input",
                    event => {

                        this.libraryFilters.search =
                            event.target.value;


                        this.render(
                            this.container
                        );


                        const newSearchInput =
                            this.container.querySelector(
                                "#library-search-input"
                            );


                        if (newSearchInput) {

                            newSearchInput.focus();


                            newSearchInput.setSelectionRange(
                                newSearchInput.value.length,
                                newSearchInput.value.length
                            );

                        }

                    }
                );

            }


            const clearSearch =
                container.querySelector(
                    '[data-action="clear-search"]'
                );


            if (clearSearch) {

                clearSearch.addEventListener(
                    "click",
                    event => {

                        event.preventDefault();

                        this.libraryFilters.search =
                            "";

                        this.render(
                            this.container
                        );

                    }
                );

            }


            const statusFilter =
                container.querySelector(
                    "#library-status-filter"
                );


            if (statusFilter) {

                statusFilter.addEventListener(
                    "change",
                    event => {

                        this.libraryFilters.status =
                            event.target.value;

                        this.render(
                            this.container
                        );

                    }
                );

            }


            const genreFilter =
                container.querySelector(
                    "#library-genre-filter"
                );


            if (genreFilter) {

                genreFilter.addEventListener(
                    "change",
                    event => {

                        this.libraryFilters.genre =
                            event.target.value;

                        this.render(
                            this.container
                        );

                    }
                );

            }


            const typeFilter =
                container.querySelector(
                    "#library-type-filter"
                );


            if (typeFilter) {

                typeFilter.addEventListener(
                    "change",
                    event => {

                        this.libraryFilters.type =
                            event.target.value;

                        this.render(
                            this.container
                        );

                    }
                );

            }


            const sortFilter =
                container.querySelector(
                    "#library-sort-filter"
                );


            if (sortFilter) {

                sortFilter.addEventListener(
                    "change",
                    event => {

                        this.libraryFilters.sort =
                            event.target.value;

                        this.render(
                            this.container
                        );

                    }
                );

            }


            const archivedToggle =
                container.querySelector(
                    "#library-archived-toggle"
                );


            if (archivedToggle) {

                archivedToggle.addEventListener(
                    "change",
                    event => {

                        this.libraryFilters.showArchived =
                            event.target.checked;

                        this.render(
                            this.container
                        );

                    }
                );

            }

        },


        /*
        =====================================================
        CREATE PROJECT MODAL
        =====================================================
        */

        showCreateProjectModal() {

            this.editingProjectId =
                null;

            this.projectImageDraft =
                null;


            this.showProjectFormModal(
                null
            );

        },


        /*
        =====================================================
        EDIT PROJECT MODAL
        =====================================================
        */

        showEditProjectModal(projectId) {

            const project =
                this.getProject(
                    projectId
                );


            if (!project) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return;

            }


            this.editingProjectId =
                projectId;

            this.projectImageDraft =
                this.normalizeProjectImageAsset(
                    project.image
                );


            this.showProjectFormModal(
                project
            );

        },


        /*
        =====================================================
        PROJECT FORM MODAL
        =====================================================
        */

        showProjectFormModal(project, preservedState = null) {

            if (!this.modalContainer) {

                this.modalContainer =
                    document.getElementById(
                        "modal-container"
                    );

            }


            if (!this.modalContainer) {

                this.core.notify(
                    "Project interface is unavailable.",
                    "error"
                );

                return;

            }


            const isEditing =
                Boolean(
                    project
                );


            const safeValue =
                value =>
                    this.escapeHTML(
                        value ?? ""
                    );


            const currentType =
                String(
                    project?.type ||
                    "Novel"
                ).trim() || "Novel";


            const currentStatus =
                String(
                    project?.status ||
                    "Draft"
                ).trim() || "Draft";


            const currentGenre =
                this.getProjectGenreTags(
                    project
                ).join(", ");


            const typeOptions =
                this.getProjectFormTypeOptions(
                    currentType
                );


            const statusOptions =
                this.getProjectFormStatusOptions(
                    currentStatus
                );


            const genreSuggestions =
                this.getProjectFormGenreSuggestions(
                    currentGenre
                );


            const targetWordsValue =
                this.getProjectTargetWords(
                    project
                );


            this.modalContainer.innerHTML = `

                <div
                    class="project-modal-backdrop"
                >

                    <section
                        class="project-modal"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="project-modal-title"
                    >

                        <header class="project-modal-header">

                            <div>

                                <p class="eyebrow">

                                    ${
                                        isEditing
                                            ? "EDIT PROJECT"
                                            : "NEW PROJECT"
                                    }

                                </p>

                                <h2 id="project-modal-title">

                                    ${
                                        isEditing
                                            ? "Edit Your Story"
                                            : "Create Your Story"
                                    }

                                </h2>

                                <p>

                                    ${
                                        isEditing
                                            ? "Update your project's details."
                                            : "Set up the foundation for your new project."
                                    }

                                </p>

                            </div>


                            <button
                                type="button"
                                class="project-modal-close"
                                data-action="close-project-modal"
                                aria-label="Close"
                            >
                                ×
                            </button>

                        </header>


                        <form
                            id="project-form"
                            class="project-form"
                            novalidate
                        >

                            <div class="project-form-grid">

                                <div
                                    class="
                                        form-field
                                        form-field-wide
                                    "
                                >

                                    <label
                                        for="project-name"
                                    >
                                        Project Title
                                    </label>

                                    <input
                                        id="project-name"
                                        name="name"
                                        type="text"
                                        maxlength="160"
                                        autocomplete="off"
                                        placeholder="Enter your story title"
                                        value="${safeValue(
                                            project?.name ||
                                            project?.title ||
                                            ""
                                        )}"
                                        required
                                    />

                                    <span
                                        class="form-error"
                                        data-error-for="name"
                                    ></span>

                                </div>


                                <div class="form-field">

                                    <label
                                        for="project-author"
                                    >
                                        Author
                                    </label>

                                    <input
                                        id="project-author"
                                        name="author"
                                        type="text"
                                        maxlength="120"
                                        autocomplete="name"
                                        placeholder="Author name"
                                        value="${safeValue(
                                            project?.author ||
                                            ""
                                        )}"
                                    />

                                </div>


                                <div class="form-field form-field-wide">

                                    <label>
                                        Project Image
                                    </label>

                                    ${this.renderProjectImagePicker()}

                                </div>


                                <div class="form-field">

                                    <label
                                        for="project-genre"
                                    >
                                        Genre Tags
                                    </label>

                                    <input
                                        id="project-genre"
                                        name="genre"
                                        type="text"
                                        list="project-genre-suggestions"
                                        maxlength="300"
                                        autocomplete="off"
                                        placeholder="Add one or more genres, separated by commas"
                                        value="${safeValue(
                                            currentGenre
                                        )}"
                                    />

                                    <datalist
                                        id="project-genre-suggestions"
                                    >

                                        ${genreSuggestions
                                            .map(
                                                genreOption => `
                                                    <option
                                                        value="${safeValue(genreOption)}"
                                                    ></option>
                                                `
                                            )
                                            .join("")}

                                    </datalist>

                                    ${this.renderGenreTypeDescriptions()}

                                </div>


                                <div class="form-field">

                                    <label
                                        for="project-type"
                                    >
                                        Project Type
                                    </label>

                                    <select
                                        id="project-type"
                                        name="type"
                                    >

                                        ${this.renderProjectFormSelectOptions(
                                            typeOptions,
                                            currentType
                                        )}

                                    </select>

                                </div>


                                <div class="form-field">

                                    <label
                                        for="project-status"
                                    >
                                        Status
                                    </label>

                                    <select
                                        id="project-status"
                                        name="status"
                                    >

                                        ${this.renderProjectFormSelectOptions(
                                            statusOptions,
                                            currentStatus
                                        )}

                                    </select>

                                </div>


                                <div class="form-field">

                                    <label
                                        for="project-series"
                                    >
                                        Series
                                    </label>

                                    <input
                                        id="project-series"
                                        name="series"
                                        type="text"
                                        maxlength="160"
                                        placeholder="Standalone or series name"
                                        value="${safeValue(
                                            project?.series ||
                                            ""
                                        )}"
                                    />

                                </div>


                                <div class="form-field">

                                    <label
                                        for="project-target"
                                    >
                                        Target Words
                                    </label>

                                    <input
                                        id="project-target"
                                        name="targetWords"
                                        type="number"
                                        min="0"
                                        max="10000000"
                                        step="1000"
                                        value="${
                                            Number.isFinite(
                                                targetWordsValue
                                            )
                                                ? targetWordsValue
                                                : ""
                                        }"
                                    />

                                    <span
                                        class="form-error"
                                        data-error-for="targetWords"
                                    ></span>

                                </div>


                                <div
                                    class="
                                        form-field
                                        form-field-wide
                                    "
                                >

                                    <label
                                        for="project-description"
                                    >
                                        Description
                                    </label>

                                    <textarea
                                        id="project-description"
                                        name="description"
                                        maxlength="2000"
                                        rows="4"
                                        placeholder="What is this story about?"
                                    >${safeValue(
                                        project?.description ||
                                        ""
                                    )}</textarea>

                                </div>

                            </div>


                            <footer class="project-modal-footer">

                                <button
                                    type="button"
                                    class="button button-secondary"
                                    data-action="close-project-modal"
                                >
                                    Cancel
                                </button>

                                <button
                                    type="submit"
                                    class="button button-primary"
                                >

                                    ${
                                        isEditing
                                            ? "Save Changes"
                                            : "Create Project"
                                    }

                                </button>

                            </footer>

                        </form>

                    </section>

                </div>

            `;


            this.modalContainer.classList.add(
                "active"
            );


            const genre =
                document.getElementById(
                    "project-genre"
                );


            const type =
                document.getElementById(
                    "project-type"
                );


            const status =
                document.getElementById(
                    "project-status"
                );


            if (genre) {

                genre.value =
                    this.getProjectGenreTags(
                        project
                    ).join(", ");

            }


            if (type) {

                type.value =
                    project?.type ||
                    "Novel";

            }


            if (status) {

                status.value =
                    project?.status ||
                    "Draft";

            }


            this.bindProjectFormEvents();


            const form =
                document.getElementById(
                    "project-form"
                );


            if (form) {

                this.applyProjectFormDraft(
                    form,
                    preservedState?.draft || null
                );

                if (
                    typeof preservedState?.baseline === "string"
                ) {

                    this.modalFormBaseline =
                        preservedState.baseline;

                    this.modalFormDirty =
                        Boolean(
                            preservedState.dirty
                        );

                    this.updateModalFormDirtyState(
                        form
                    );

                } else {

                    this.setModalFormBaseline(
                        form
                    );

                }

            }


            window.setTimeout(
                () => {

                    document
                        .getElementById(
                            "project-name"
                        )
                        ?.focus();

                },
                0
            );

        },


        /*
        =====================================================
        PROJECT FORM EVENTS
        =====================================================
        */

        bindProjectFormEvents() {

            const form =
                document.getElementById(
                    "project-form"
                );

            const projectImageInput =
                document.getElementById(
                    "project-image-input"
                );


            if (!form) {

                return;

            }


            form.addEventListener(
                "submit",
                event => {

                    event.preventDefault();

                    this.handleProjectFormSubmit(
                        form
                    );

                }
            );


            const markDirty =
                () => {

                    this.updateModalFormDirtyState(
                        form
                    );

                };


            form.addEventListener(
                "input",
                markDirty
            );

            form.addEventListener(
                "change",
                markDirty
            );


            this.modalContainer
                .querySelectorAll(
                    '[data-action="close-project-modal"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.attemptCloseModal();

                            }
                        );

                    }
                );


            this.modalContainer
                .querySelector('[data-action="choose-project-image"]')
                ?.addEventListener(
                    "click",
                    async event => {

                        event.preventDefault();

                        if (window.AuthorOSDesktop?.isTauri?.()) {

                            const selected =
                                await window.AuthorOSDesktop.openFile(
                                    {
                                        filters: [
                                            {
                                                name: "Images",
                                                extensions: ["jpg", "jpeg", "png", "webp"]
                                            }
                                        ]
                                    }
                                );

                            if (selected.canceled || !selected.ok) {

                                if (!selected.canceled && selected.error) {
                                    this.core.notify(selected.error, "error");
                                }

                                return;

                            }

                            const file = selected.file || null;

                            if (!file || !window.AuthorOSImageAssets) {
                                return;
                            }

                            const processed =
                                await window.AuthorOSImageAssets.processFile(
                                    file,
                                    {
                                        maxFileBytes: 5 * 1024 * 1024,
                                        maxWidth: 960,
                                        maxHeight: 640,
                                        outputType: "image/webp",
                                        quality: 0.82
                                    }
                                );

                            if (!processed.ok) {

                                this.core.notify(
                                    processed.error || "Unable to use this image. Please choose a JPG, PNG, or WEBP image within the supported file size.",
                                    "error"
                                );

                                return;

                            }

                            this.projectImageDraft =
                                processed.asset;

                            const preservedState =
                                this.captureProjectFormState(
                                    form
                                );

                            this.showProjectFormModal(
                                this.editingProjectId
                                    ? this.getProject(this.editingProjectId)
                                    : null,
                                preservedState
                            );

                            return;

                        }

                        projectImageInput?.click();

                    }
                );


            this.modalContainer
                .querySelector('[data-action="remove-project-image"]')
                ?.addEventListener(
                    "click",
                    event => {

                        event.preventDefault();

                        const preservedState =
                            this.captureProjectFormState(
                                form
                            );

                        this.projectImageDraft =
                            null;

                        this.showProjectFormModal(
                            this.editingProjectId
                                ? this.getProject(this.editingProjectId)
                                : null,
                            preservedState
                        );

                    }
                );


            projectImageInput
                ?.addEventListener(
                    "change",
                    async event => {

                        const file =
                            event?.currentTarget?.files?.[0] ||
                            null;

                        if (!file || !window.AuthorOSImageAssets) {
                            return;
                        }

                        const processed =
                            await window.AuthorOSImageAssets.processFile(
                                file,
                                {
                                    maxFileBytes: 5 * 1024 * 1024,
                                    maxWidth: 960,
                                    maxHeight: 640,
                                    outputType: "image/webp",
                                    quality: 0.82
                                }
                            );

                        projectImageInput.value =
                            "";

                        if (!processed.ok) {

                            this.core.notify(
                                processed.error || "Unable to use this image. Please choose a JPG, PNG, or WEBP image within the supported file size.",
                                "error"
                            );

                            return;

                        }

                        this.projectImageDraft =
                            processed.asset;

                        const preservedState =
                            this.captureProjectFormState(
                                form
                            );

                        this.showProjectFormModal(
                            this.editingProjectId
                                ? this.getProject(this.editingProjectId)
                                : null,
                            preservedState
                        );

                    }
                );


            this.bindModalBackdrop();


            document.addEventListener(
                "keydown",
                this.handleEscapeKey
            );

        },


        /*
        =====================================================
        HANDLE FORM SUBMIT
        =====================================================
        */

        handleProjectFormSubmit(form) {

            const formData =
                new FormData(
                    form
                );


            const name =
                String(
                    formData.get("name") ||
                    ""
                ).trim();


            const author =
                String(
                    formData.get("author") ||
                    ""
                ).trim();


            const genreTags =
                this.parseGenreTags(
                    String(
                        formData.get("genre") ||
                        ""
                    )
                );

            const genre =
                genreTags[0] || "";


            const type =
                String(
                    formData.get("type") ||
                    "Novel"
                ).trim();


            const status =
                String(
                    formData.get("status") ||
                    "Draft"
                ).trim();


            const series =
                String(
                    formData.get("series") ||
                    ""
                ).trim();


            const description =
                String(
                    formData.get("description") ||
                    ""
                ).replaceAll(
                    "\r\n",
                    "\n"
                );


            const targetWordsRaw =
                String(
                    formData.get("targetWords") ||
                    ""
                ).trim();


            const targetWords =
                targetWordsRaw === ""
                    ? 0
                    : Number(
                        targetWordsRaw
                    );


            this.clearFormErrors();


            const validation =
                window.AuthorOSValidation;


            if (
                !validation ||
                !validation.required(
                    name
                )
            ) {

                this.setFormError(
                    "name",
                    "Please enter a project title."
                );

                document
                    .getElementById(
                        "project-name"
                    )
                    ?.focus();

                return;

            }


            if (
                name.length <
                2
            ) {

                this.setFormError(
                    "name",
                    "Project title must contain at least 2 characters."
                );

                document
                    .getElementById(
                        "project-name"
                    )
                    ?.focus();

                return;

            }


            if (
                !Number.isFinite(
                    targetWords
                ) ||
                targetWords < 0 ||
                !Number.isInteger(
                    targetWords
                )
            ) {

                this.setFormError(
                    "targetWords",
                    "Target words must be a whole number of 0 or greater."
                );

                document
                    .getElementById(
                        "project-target"
                    )
                    ?.focus();

                return;

            }


            const editingProject =
                this.editingProjectId
                    ? this.getProject(
                        this.editingProjectId
                    )
                    : null;


            const supportedTypes =
                this.getProjectFormTypeOptions(
                    editingProject?.type
                );

            const supportedStatuses =
                this.getProjectFormStatusOptions(
                    editingProject?.status
                );


            if (
                !supportedTypes.includes(
                    type
                )
            ) {

                this.core.notify(
                    "Project type is not supported.",
                    "error"
                );

                return;

            }


            if (
                !supportedStatuses.includes(
                    status
                )
            ) {

                this.core.notify(
                    "Project status is not supported.",
                    "error"
                );

                return;

            }


            if (
                this.editingProjectId
            ) {

                this.updateProject({

                    name,

                    author,

                    genre,

                    genreTags,

                    type,

                    status,

                    series,

                    description,

                    targetWords,

                    image:
                        this.projectImageDraft

                });

                return;

            }


            this.createProject({

                name,

                author,

                genre,

                genreTags,

                type,

                status,

                series,

                description,

                targetWords,

                image:
                    this.projectImageDraft

            });

        },


        /*
        =====================================================
        CREATE PROJECT
        =====================================================
        */

        createProject(data) {

            const now =
                new Date().toISOString();


            const project = {

                id:
                    this.generateProjectId(),


                name:
                    data.name,


                title:
                    data.name,


                author:
                    data.author,


                genre:
                    data.genre,

                genreTags:
                    this.parseGenreTags(
                        data.genreTags || data.genre
                    ),


                type:
                    data.type,


                status:
                    data.status,


                series:
                    data.series,


                description:
                    data.description,

                image:
                    this.normalizeProjectImageAsset(
                        data.image
                    ),


                targetWords:
                    data.targetWords,


                targetWordCount:
                    data.targetWords,


                cover:
                    null,


                createdAt:
                    now,


                updatedAt:
                    now,


                lastModified:
                    now,


                lastOpened:
                    null,


                statistics: {

                    words:
                        0,

                    characters:
                        0,

                    chapters:
                        0,

                    scenes:
                        0

                },


                manuscript: {

                    chapters: []

                }

            };


            const projects =
                this.getProjects();


            projects.push(
                project
            );


            if (
                this.saveProjects(
                    projects,
                    {
                        source:
                            "create"
                    }
                )
            ) {

                this.core.state.set(
                    "currentProject",
                    project
                );


                this.core.events.emit(
                    "project:created",
                    project
                );


                this.closeModal();


                this.refreshProjectViews();


                this.core.notify(
                    `Project "${project.name}" created.`,
                    "success"
                );

            }

        },


        /*
        =====================================================
        UPDATE PROJECT
        =====================================================
        */

        updateProject(data) {

            const projects =
                this.getProjects();


            const index =
                projects.findIndex(
                    project =>
                        project.id ===
                        this.editingProjectId
                );


            if (
                index === -1
            ) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return;

            }


            const project =
                projects[index];


            const now =
                new Date().toISOString();

            const updatedProject = {

                ...project,

                name:
                    data.name,

                title:
                    data.name,

                author:
                    data.author,

                genre:
                    data.genre,

                genreTags:
                    this.parseGenreTags(
                        data.genreTags || data.genre
                    ),

                type:
                    data.type,

                status:
                    data.status,

                series:
                    data.series,

                description:
                    data.description,

                image:
                    this.normalizeProjectImageAsset(
                        data.image
                    ),

                targetWords:
                    data.targetWords,

                targetWordCount:
                    data.targetWords,

                updatedAt:
                    now,

                lastModified:
                    now

            };


            projects[index] =
                updatedProject;


            if (
                this.saveProjects(
                    projects,
                    {
                        source:
                            "update"
                    }
                )
            ) {

                const currentProject =
                    this.core.state.get(
                        "currentProject"
                    );


                if (
                    currentProject &&
                    currentProject.id ===
                    updatedProject.id
                ) {

                    this.core.state.set(
                        "currentProject",
                        updatedProject
                    );

                }


                this.core.events.emit(
                    "project:updated",
                    updatedProject
                );


                this.closeModal();


                this.refreshProjectViews();


                this.core.notify(
                    `Project "${updatedProject.name}" updated.`,
                    "success"
                );

            }

        },


        /*
        =====================================================
        OPEN PROJECT
        =====================================================
        */

        openProject(projectId) {

            const currentProject =
                this.core.state.get(
                    "currentProject"
                );


            if (
                currentProject &&
                currentProject.id !==
                projectId &&
                this.core.autosave?.dirty
            ) {

                this.core.autosave.flushProject(
                    currentProject.id,
                    {
                        reason:
                            "project-switch"
                    }
                );

            }

            const projects =
                this.getProjects();


            const index =
                projects.findIndex(
                    project =>
                        project.id ===
                        projectId
                );


            if (
                index === -1
            ) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return;

            }


            const project =
                projects[index];


            if (
                project.status ===
                "Archived"
            ) {

                this.core.notify(
                    "Archived projects must be unarchived before opening.",
                    "info"
                );

                return;

            }


            const now =
                new Date().toISOString();


            project.lastOpened =
                now;


            project.updatedAt =
                project.updatedAt ||
                now;


            projects[index] =
                project;


            if (
                !this.saveProjects(
                    projects,
                    {
                        source:
                            "open"
                    }
                )
            ) {

                return;

            }


            const syncedProject =
                this.getProject(
                    projectId
                );


            if (!syncedProject) {

                this.core.notify(
                    "The project could not be loaded after saving.",
                    "error"
                );

                return;

            }


            this.core.state.set(
                "currentProject",
                syncedProject
            );


            this.core.storage.saveActiveProjectId(
                syncedProject.id
            );


            this.projectWorkspaceSection =
                "overview";


            this.core.events.emit(
                "project:opened",
                syncedProject
            );


            this.core.notify(
                `Project "${syncedProject.name}" opened.`,
                "success"
            );


            this.core.navigation.navigate(
                "project-workspace"
            );

        },


        /*
        =====================================================
        ARCHIVE PROJECT
        =====================================================
        */

        archiveProject(projectId) {

            const projects =
                this.getProjects();


            const project =
                projects.find(
                    item =>
                        item.id ===
                        projectId
                );


            if (!project) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return;

            }


            if (
                project.status ===
                "Archived"
            ) {

                return;

            }


            project.previousStatus =
                project.status ||
                "Draft";


            project.status =
                "Archived";


            project.updatedAt =
                new Date().toISOString();


            project.lastModified =
                project.updatedAt;


            if (
                this.saveProjects(
                    projects,
                    {
                        source:
                            "archive"
                    }
                )
            ) {

                const currentProject =
                    this.core.state.get(
                        "currentProject"
                    );


                if (
                    currentProject &&
                    currentProject.id ===
                    project.id
                ) {

                    this.core.state.set(
                        "currentProject",
                        project
                    );

                }


                this.core.events.emit(
                    "project:archived",
                    project
                );


                this.render(
                    this.container
                );


                this.core.notify(
                    `Project "${project.name}" archived.`,
                    "success"
                );

            }

        },


        /*
        =====================================================
        UNARCHIVE PROJECT
        =====================================================
        */

        unarchiveProject(projectId) {

            const projects =
                this.getProjects();


            const project =
                projects.find(
                    item =>
                        item.id ===
                        projectId
                );


            if (!project) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return;

            }


            if (
                project.status !==
                "Archived"
            ) {

                return;

            }


            project.status =
                project.previousStatus ||
                "Draft";


            delete project.previousStatus;


            project.updatedAt =
                new Date().toISOString();


            project.lastModified =
                project.updatedAt;


            if (
                this.saveProjects(
                    projects,
                    {
                        source:
                            "unarchive"
                    }
                )
            ) {

                this.core.events.emit(
                    "project:unarchived",
                    project
                );


                this.render(
                    this.container
                );


                this.core.notify(
                    `Project "${project.name}" restored.`,
                    "success"
                );

            }

        },


        /*
        =====================================================
        DELETE CONFIRMATION
        =====================================================
        */

        showDeleteProjectModal(projectId) {

            const project =
                this.getProject(
                    projectId
                );


            if (!project) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                return;

            }


            this.deletingProjectId =
                projectId;


            this.modalContainer.innerHTML = `

                <div
                    class="project-modal-backdrop"
                >

                    <section
                        class="
                            project-modal
                            project-delete-modal
                        "
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="delete-project-title"
                    >

                        <header
                            class="project-modal-header"
                        >

                            <div>

                                <p class="eyebrow">
                                    DELETE PROJECT
                                </p>

                                <h2
                                    id="delete-project-title"
                                >
                                    Delete ${this.escapeHTML(
                                        project.name ||
                                        project.title ||
                                        "this story"
                                    )}?
                                </h2>

                                <p>
                                    This action permanently removes
                                    the project from Author Studio.
                                </p>

                            </div>


                            <button
                                type="button"
                                class="project-modal-close"
                                data-action="close-delete-modal"
                                aria-label="Close"
                            >
                                ×
                            </button>

                        </header>


                        <div
                            class="project-delete-content"
                        >

                            <div
                                class="project-delete-warning"
                            >
                                !
                            </div>


                            <p>
                                You are about to permanently delete:
                            </p>


                            <strong>
                                ${this.escapeHTML(
                                    project.name ||
                                    project.title ||
                                    "Untitled Project"
                                )}
                            </strong>


                            <p class="project-delete-note">
                                Your manuscript, metadata, and
                                project information stored inside
                                this project will be removed.
                            </p>

                        </div>


                        <footer
                            class="project-modal-footer"
                        >

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="close-delete-modal"
                            >
                                Cancel
                            </button>


                            <button
                                type="button"
                                class="
                                    button
                                    button-danger
                                "
                                data-action="confirm-delete-project"
                            >
                                Delete Permanently
                            </button>

                        </footer>

                    </section>

                </div>

            `;


            this.modalContainer.classList.add(
                "active"
            );


            this.bindDeleteModalEvents();

        },


        /*
        =====================================================
        DELETE MODAL EVENTS
        =====================================================
        */

        bindDeleteModalEvents() {

            this.modalContainer
                .querySelectorAll(
                    '[data-action="close-delete-modal"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.closeModal();

                            }
                        );

                    }
                );


            const confirm =
                this.modalContainer
                    .querySelector(
                        '[data-action="confirm-delete-project"]'
                    );


            if (confirm) {

                confirm.addEventListener(
                    "click",
                    event => {

                        event.preventDefault();

                        this.deleteProject();

                    }
                );

            }


            this.bindModalBackdrop();


            document.addEventListener(
                "keydown",
                this.handleEscapeKey
            );

        },


        /*
        =====================================================
        DELETE PROJECT
        =====================================================
        */

        deleteProject() {

            const projectId =
                this.deletingProjectId;


            if (!projectId) {

                return;

            }


            const projects =
                this.getProjects();


            const index =
                projects.findIndex(
                    project =>
                        project.id ===
                        projectId
                );


            if (
                index === -1
            ) {

                this.core.notify(
                    "Project could not be found.",
                    "error"
                );

                this.closeModal();

                return;

            }


            const project =
                projects[index];


            const preDeleteBackup =
                this.createProjectBackup(
                    projectId,
                    {
                        type:
                            "pre-delete",
                        reason:
                            "Pre-Delete Backup",
                        silent: true,
                        requireCleanProject: true
                    }
                );


            if (!preDeleteBackup) {

                this.core.notify(
                    "Project deletion was cancelled because recovery backup could not be created.",
                    "error"
                );

                return;

            }


            projects.splice(
                index,
                1
            );


            if (
                !this.saveProjects(
                    projects,
                    {
                        source:
                            "delete"
                    }
                )
            ) {

                return;

            }


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

                this.core.storage.saveActiveProjectId(
                    null
                );

            }


            if (
                this.core.storage.loadActiveProjectId() ===
                projectId
            ) {

                this.core.storage.saveActiveProjectId(
                    null
                );

            }


            this.core.events.emit(
                "project:deleted",
                project
            );


            this.core.autosave?.removeProjectTracking(
                projectId
            );


            this.deletingProjectId =
                null;


            this.deletingBackupId =
                null;


            this.restoringBackupId =
                null;


            this.closeModal();


            if (
                this.core.navigation &&
                typeof this.core.navigation.navigate ===
                "function"
            ) {

                this.core.navigation.navigate(
                    "projects"
                );

            } else {

                this.refreshProjectViews();

            }


            this.core.notify(
                `Project "${project.name}" deleted.`,
                "success"
            );

        },


        /*
        =====================================================
        BACKUP MANAGER ACTIONS
        =====================================================
        */

        createProjectBackup(
            projectId,
            options = {}
        ) {

            const activeProject =
                this.getProject(
                    projectId
                );


            if (!activeProject) {

                this.core.notify(
                    "Active project is unavailable for backup.",
                    "error"
                );

                return null;

            }


            if (
                options.requireCleanProject &&
                this.core.autosave?.dirty
            ) {

                const flushed =
                    this.core.autosave.flushProject(
                        projectId,
                        {
                            reason:
                                "backup-preparation"
                        }
                    );


                if (!flushed) {

                    this.core.notify(
                        "Current project changes could not be saved before backup.",
                        "error"
                    );

                    return null;

                }

            }


            const snapshot =
                this.cloneProjectData(
                    activeProject
                );


            if (!snapshot) {

                this.core.notify(
                    "Project backup failed because the project state could not be copied.",
                    "error"
                );

                return null;

            }


            const now =
                new Date().toISOString();


            const backup = {

                id:
                    this.generateBackupId(),

                projectId:
                    activeProject.id,

                projectName:
                    this.getProjectTitle(
                        activeProject
                    ),

                createdAt:
                    now,

                type:
                    options.type ||
                    "manual",

                reason:
                    options.reason ||
                    "Manual Backup",

                schemaVersion:
                    this.backupSchemaVersion,

                snapshot

            };


            try {

                const allBackups =
                    this.core.storage.loadBackups();


                const backupsWithNew = [
                    ...allBackups,
                    backup
                ];


                const retained =
                    this.enforceBackupRetention(
                        backupsWithNew,
                        backup.projectId
                    );


                const saved =
                    this.core.storage.saveBackups(
                        retained
                    );


                if (!saved) {

                    throw new Error(
                        "Backup persistence failed."
                    );

                }


                if (
                    !options.silent
                ) {

                    this.core.notify(
                        `${backup.reason} created.`,
                        "success"
                    );

                }


                this.core.events.emit(
                    "storage:changed"
                );


                if (
                    this.projectWorkspaceSection ===
                    "backups"
                ) {

                    this.renderProjectWorkspace(
                        this.container
                    );

                }


                return backup;

            } catch (error) {

                console.error(
                    "AuthorOS backup creation failed:",
                    error
                );

                this.core.notify(
                    "Backup could not be created.",
                    "error"
                );

                return null;

            }

        },


        enforceBackupRetention(
            backups,
            projectId
        ) {

            const source =
                Array.isArray(backups)
                    ? backups
                    : [];


            const manual =
                source.filter(
                    backup =>
                        backup?.projectId ===
                            projectId &&
                        backup?.type ===
                            "manual"
                );

            const automatic =
                source
                    .filter(
                        backup =>
                            backup?.projectId ===
                                projectId &&
                            backup?.type !==
                                "manual"
                    )
                    .sort(
                        (left, right) =>
                            new Date(
                                right.createdAt
                            ).getTime() -
                            new Date(
                                left.createdAt
                            ).getTime()
                    );


            const keepAutomatic =
                automatic.slice(
                    0,
                    20
                );


            const keepIds =
                new Set(
                    [
                        ...manual,
                        ...keepAutomatic
                    ].map(
                        backup =>
                            backup.id
                    )
                );


            return source.filter(
                backup =>
                    backup?.projectId !==
                        projectId ||
                    keepIds.has(
                        backup.id
                    )
            );

        },


        showRestoreBackupModal(
            backupId,
            projectId
        ) {

            const backup =
                this.core.storage.loadBackup(
                    backupId
                );


            if (
                !this.isValidBackupRecord(
                    backup
                )
            ) {

                this.core.notify(
                    "Selected backup is unavailable or corrupted.",
                    "error"
                );

                return;

            }


            if (
                backup.projectId !==
                projectId
            ) {

                this.core.notify(
                    "This backup does not belong to the active project.",
                    "error"
                );

                return;

            }


            this.restoringBackupId =
                backupId;


            this.showBackupConfirmationModal({
                eyebrow:
                    "RESTORE BACKUP",
                title:
                    "Restore this backup?",
                message:
                    "Your current project state will be replaced by the selected backup.",
                confirmLabel:
                    "Restore Backup",
                confirmAction:
                    "confirm-restore-backup",
                danger: true
            });

        },


        showDeleteBackupModal(
            backupId,
            projectId
        ) {

            const backup =
                this.core.storage.loadBackup(
                    backupId
                );


            if (
                !this.isValidBackupRecord(
                    backup
                )
            ) {

                this.core.notify(
                    "Selected backup is unavailable or corrupted.",
                    "error"
                );

                return;

            }


            if (
                backup.projectId !==
                projectId
            ) {

                this.core.notify(
                    "This backup does not belong to the active project.",
                    "error"
                );

                return;

            }


            this.deletingBackupId =
                backupId;


            this.showBackupConfirmationModal({
                eyebrow:
                    "DELETE BACKUP",
                title:
                    "Delete this backup?",
                message:
                    "This backup will be removed from recovery history.",
                confirmLabel:
                    "Delete Backup",
                confirmAction:
                    "confirm-delete-backup",
                danger: true
            });

        },


        showBackupConfirmationModal(config) {

            if (!this.modalContainer) {

                this.modalContainer =
                    document.getElementById(
                        "modal-container"
                    );

            }


            if (!this.modalContainer) {

                this.core.notify(
                    "Backup confirmation dialog is unavailable.",
                    "error"
                );

                return;

            }


            this.modalContainer.innerHTML = `

                <div
                    class="project-modal-backdrop"
                >

                    <section
                        class="project-modal project-delete-modal"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="backup-confirm-title"
                    >

                        <header class="project-modal-header">

                            <div>

                                <p class="eyebrow">
                                    ${this.escapeHTML(config.eyebrow || "BACKUP")}
                                </p>

                                <h2 id="backup-confirm-title">
                                    ${this.escapeHTML(config.title || "Confirm action")}
                                </h2>

                                <p>
                                    ${this.escapeHTML(config.message || "")}
                                </p>

                            </div>

                            <button
                                type="button"
                                class="project-modal-close"
                                data-action="close-backup-modal"
                                aria-label="Close"
                            >
                                ×
                            </button>

                        </header>


                        <footer class="project-modal-footer">

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="close-backup-modal"
                            >
                                Cancel
                            </button>

                            <button
                                type="button"
                                class="button ${config.danger ? "button-danger" : "button-primary"}"
                                data-action="${this.escapeHTML(config.confirmAction || "confirm-backup-action")}" 
                            >
                                ${this.escapeHTML(config.confirmLabel || "Confirm")}
                            </button>

                        </footer>

                    </section>

                </div>

            `;


            this.modalContainer.classList.add(
                "active"
            );


            this.bindBackupModalEvents();

        },


        bindBackupModalEvents() {

            this.modalContainer
                ?.querySelectorAll(
                    '[data-action="close-backup-modal"]'
                )
                .forEach(
                    button => {

                        button.addEventListener(
                            "click",
                            event => {

                                event.preventDefault();

                                this.closeModal();

                            }
                        );

                    }
                );


            this.modalContainer
                ?.querySelector(
                    '[data-action="confirm-restore-backup"]'
                )
                ?.addEventListener(
                    "click",
                    event => {

                        event.preventDefault();

                        this.restoreProjectBackup(
                            this.restoringBackupId
                        );

                    }
                );


            this.modalContainer
                ?.querySelector(
                    '[data-action="confirm-delete-backup"]'
                )
                ?.addEventListener(
                    "click",
                    event => {

                        event.preventDefault();

                        this.deleteProjectBackup(
                            this.deletingBackupId
                        );

                    }
                );


            this.bindModalBackdrop();

            document.addEventListener(
                "keydown",
                this.handleEscapeKey
            );

        },


        restoreProjectBackup(backupId) {

            const backup =
                this.core.storage.loadBackup(
                    backupId
                );

            const activeProject =
                this.getActiveProject();


            if (!activeProject) {

                this.core.notify(
                    "No active project is available for restore.",
                    "error"
                );

                return false;

            }


            if (
                !this.isValidBackupRecord(
                    backup
                )
            ) {

                this.core.notify(
                    "Backup is missing or incompatible.",
                    "error"
                );

                return false;

            }


            if (
                backup.projectId !==
                activeProject.id
            ) {

                this.core.notify(
                    "This backup belongs to a different project and cannot be restored here.",
                    "error"
                );

                return false;

            }


            const safetyBackup =
                this.createProjectBackup(
                    activeProject.id,
                    {
                        type:
                            "safety-pre-restore",
                        reason:
                            "Safety Backup Before Restore",
                        silent: true,
                        requireCleanProject: true
                    }
                );


            if (!safetyBackup) {

                this.core.notify(
                    "Restore cancelled because safety backup could not be created.",
                    "error"
                );

                return false;

            }


            const restoredSnapshot =
                this.cloneProjectData(
                    backup.snapshot
                );


            if (!restoredSnapshot) {

                this.core.notify(
                    "Backup snapshot is malformed and cannot be restored.",
                    "error"
                );

                return false;

            }


            const now =
                new Date().toISOString();


            const restoredProject =
                this.normalizeProject({
                    ...restoredSnapshot,
                    id: activeProject.id,
                    updatedAt: now,
                    lastModified: now
                });


            if (!restoredProject) {

                this.core.notify(
                    "Backup data could not be normalized for restore.",
                    "error"
                );

                return false;

            }


            const projects =
                this.getProjects();


            const index =
                projects.findIndex(
                    project =>
                        project.id ===
                        activeProject.id
                );


            if (
                index === -1
            ) {

                this.core.notify(
                    "Active project could not be found for restore.",
                    "error"
                );

                return false;

            }


            projects[index] =
                restoredProject;


            const saved =
                this.saveProjects(
                    projects,
                    {
                        source:
                            "backup-restore"
                    }
                );


            if (!saved) {

                this.core.notify(
                    "Backup restore failed during persistence.",
                    "error"
                );

                return false;

            }


            this.core.autosave?.clearProjectDirty(
                activeProject.id
            );

            this.projectWorkspaceSection =
                "overview";


            this.closeModal();

            this.renderProjectWorkspace(
                this.container
            );


            this.core.notify(
                `Restored backup from ${this.formatProjectDate(backup.createdAt)}.`,
                "success"
            );

            this.core.setStatus(
                "Saved"
            );


            return true;

        },


        deleteProjectBackup(backupId) {

            const backup =
                this.core.storage.loadBackup(
                    backupId
                );


            if (
                !this.isValidBackupRecord(
                    backup
                )
            ) {

                this.core.notify(
                    "Backup could not be found.",
                    "error"
                );

                return false;

            }


            const deleted =
                this.core.storage.deleteBackup(
                    backupId
                );


            if (!deleted) {

                this.core.notify(
                    "Backup deletion failed.",
                    "error"
                );

                return false;

            }


            this.deletingBackupId =
                null;

            this.closeModal();

            this.renderProjectWorkspace(
                this.container
            );

            this.core.notify(
                "Backup deleted.",
                "success"
            );


            return true;

        },


        /*
        =====================================================
        SAVE PROJECTS
        =====================================================
        */

        saveProjects(
            projects,
            options = {}
        ) {

            try {

                const report =
                    this.normalizeProjectList(
                        projects
                    );


                const normalizedProjects =
                    report.projects;

                this.core.state.set(
                    "projects",
                    normalizedProjects
                );


                const writeResult =
                    this.core.storage.saveProjects(
                        normalizedProjects
                    );


                if (!writeResult) {

                    throw new Error(
                        "Project storage write failed."
                    );

                }


                const persisted =
                    this.core.storage.loadProjects();


                const persistedReport =
                    this.normalizeProjectList(
                        persisted
                    );


                if (
                    !this.projectCollectionsMatch(
                        normalizedProjects,
                        persistedReport.projects
                    )
                ) {

                    throw new Error(
                        "Project storage verification failed."
                    );

                }


                this.core.state.set(
                    "projects",
                    persistedReport.projects
                );


                this.synchronizeCurrentProject(
                    persistedReport.projects
                );


                const now =
                    new Date().toISOString();


                this.storageSync.lastReadVerifiedAt =
                    now;

                this.storageSync.lastWriteVerifiedAt =
                    now;

                this.storageSync.lastError =
                    null;


                this.core.events.emit(
                    "project:saved",
                    {
                        source:
                            options.source ||
                            "unknown",
                        count:
                            persistedReport.projects.length
                    }
                );


                this.core.events.emit(
                    "storage:changed"
                );


                this.core.setStatus(
                    "Projects saved"
                );


                return true;

            } catch (error) {

                console.error(
                    "AuthorOS project persistence error:",
                    error
                );


                this.storageSync.lastError =
                    error.message;


                this.core.notify(
                    "The project changes could not be saved.",
                    "error"
                );


                return false;

            }

        },


        /*
        =====================================================
        GENERATE PROJECT ID
        =====================================================
        */

        generateProjectId() {

            let id;


            do {

                id =
                    "project-" +
                    Date.now().toString(36) +
                    "-" +
                    Math.random()
                        .toString(36)
                        .slice(2, 8);

            } while (
                this.getProjects()
                    .some(
                        project =>
                            project.id === id
                    )
            );


            return id;

        },


        /*
        =====================================================
        FORM ERRORS
        =====================================================
        */

        setFormError(
            field,
            message
        ) {

            const error =
                this.modalContainer
                    ?.querySelector(
                        `[data-error-for="${field}"]`
                    );


            if (error) {

                error.textContent =
                    message;

            }


            const input =
                document.getElementById(
                    `project-${field}`
                );


            const fallbackInput =
                this.modalContainer
                    ?.querySelector(
                        `[name="${field}"]`
                    );


            if (input) {

                input.classList.add(
                    "form-input-error"
                );

                return;

            }


            if (fallbackInput) {

                fallbackInput.classList.add(
                    "form-input-error"
                );

            }

        },


        clearFormErrors() {

            this.modalContainer
                ?.querySelectorAll(
                    ".form-error"
                )
                .forEach(
                    element => {

                        element.textContent =
                            "";

                    }
                );


            this.modalContainer
                ?.querySelectorAll(
                    ".form-input-error"
                )
                .forEach(
                    element => {

                        element.classList.remove(
                            "form-input-error"
                        );

                    }
                );

        },


        /*
        =====================================================
        MODAL BACKDROP
        =====================================================
        */

        bindModalBackdrop() {

            const backdrop =
                this.modalContainer
                    ?.querySelector(
                        ".project-modal-backdrop"
                    );


            if (!backdrop) {

                return;

            }


            backdrop.addEventListener(
                "click",
                event => {

                    if (
                        event.target ===
                        backdrop
                    ) {

                        this.attemptCloseModal();

                    }

                }
            );

        },


        /*
        =====================================================
        CLOSE MODAL
        =====================================================
        */

        closeModal() {

            if (
                this.modalContainer
            ) {

                this.modalContainer.innerHTML =
                    "";

                this.modalContainer.classList.remove(
                    "active"
                );

            }


            this.editingProjectId =
                null;


            this.deletingProjectId =
                null;


            this.modalFormBaseline =
                null;


            this.modalFormDirty =
                false;

            this.projectImageDraft =
                null;


            document.removeEventListener(
                "keydown",
                this.handleEscapeKey
            );

        },


        /*
        =====================================================
        ESCAPE KEY
        =====================================================
        */

        handleEscapeKey(event) {

            if (
                event.key ===
                "Escape"
            ) {

                window.AuthorOSProjects
                    .attemptCloseModal();

            }

        },


        /*
        =====================================================
        HTML ESCAPING
        =====================================================
        */

        escapeHTML(value) {

            return String(
                value ?? ""
            )

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

        },


        isValidBackupRecord(backup) {

            if (
                !backup ||
                typeof backup !== "object"
            ) {

                return false;

            }


            if (
                typeof backup.id !== "string" ||
                !backup.id.trim()
            ) {

                return false;

            }


            if (
                typeof backup.projectId !== "string" ||
                !backup.projectId.trim()
            ) {

                return false;

            }


            if (
                !backup.snapshot ||
                typeof backup.snapshot !== "object"
            ) {

                return false;

            }


            if (
                backup.schemaVersion !==
                this.backupSchemaVersion
            ) {

                return false;

            }


            const createdAt =
                new Date(
                    backup.createdAt
                );


            return !Number.isNaN(
                createdAt.getTime()
            );

        },


        formatBackupType(type) {

            if (
                type === "pre-delete"
            ) {

                return "Pre-Delete Backup";

            }


            if (
                type === "safety-pre-restore"
            ) {

                return "Safety Backup";

            }


            if (
                type === "manual"
            ) {

                return "Manual Backup";

            }


            return "Automatic Backup";

        },


        cloneProjectData(value) {

            try {

                return JSON.parse(
                    JSON.stringify(
                        value
                    )
                );

            } catch (error) {

                console.error(
                    "AuthorOS project clone failed:",
                    error
                );

                return null;

            }

        },


        generateBackupId() {

            const existing =
                new Set(
                    this.core.storage
                        .loadBackups()
                        .map(
                            backup =>
                                backup.id
                        )
                );


            let id;

            do {

                id =
                    "backup-" +
                    Date.now().toString(36) +
                    "-" +
                    Math.random()
                        .toString(36)
                        .slice(2, 8);

            } while (
                existing.has(id)
            );


            return id;

        },


        getProjectTargetWords(project) {

            const source =
                Number(
                    project?.targetWords ??
                    project?.targetWordCount
                );


            return Number.isFinite(
                source
            )
                ? Math.max(
                    0,
                    Math.trunc(
                        source
                    )
                )
                : NaN;

        },


        getProjectFormTypeOptions(currentType) {

            const defaults = [
                "Novel",
                "Novella",
                "Short Story",
                "Collection",
                "Other"
            ];


            const values = [
                ...this.getUniqueValues(
                    "type"
                ),
                ...defaults
            ];


            if (
                typeof currentType === "string" &&
                currentType.trim()
            ) {

                values.push(
                    currentType.trim()
                );

            }


            return [
                ...new Set(values)
            ];

        },


        getProjectFormStatusOptions(currentStatus) {

            const defaults = [
                "Draft",
                "Planning",
                "In Progress",
                "Editing",
                "Completed",
                "On Hold",
                "Archived"
            ];


            const values = [
                ...this.getUniqueValues(
                    "status"
                ),
                ...defaults
            ];


            if (
                typeof currentStatus === "string" &&
                currentStatus.trim()
            ) {

                values.push(
                    currentStatus.trim()
                );

            }


            return [
                ...new Set(values)
            ];

        },


        getProjectFormGenreSuggestions(currentGenre) {

            const defaults =
                this.getStandardGenreTypeCatalog().map(
                    item => item.name
                );


            const values = [
                ...this.getUniqueGenreTags(),
                ...defaults
            ];


            if (
                typeof currentGenre === "string" &&
                currentGenre.trim()
            ) {

                this.parseGenreTags(
                    currentGenre
                ).forEach(
                    tag => {
                        values.push(tag);
                    }
                );

            }


            return [
                ...new Set(values)
            ];

        },


        getStandardGenreTypeCatalog() {

            return [
                {
                    name: "Action & Adventure",
                    family: "adventure",
                    description: "Stories driven by physical risk, chases, and survival."
                },
                {
                    name: "Comedy",
                    family: "humor",
                    description: "Works intended to amuse, ranging from slapstick to satire."
                },
                {
                    name: "Drama",
                    family: "character",
                    description: "Narrative fiction focused on deep emotional character development."
                },
                {
                    name: "Fantasy",
                    family: "speculative",
                    description: "Magic, myth, folklore, and entirely invented worlds."
                },
                {
                    name: "Historical Fiction",
                    family: "historical",
                    description: "Fictional plots interwoven with authentic historical events."
                },
                {
                    name: "Horror",
                    family: "suspense",
                    description: "Content engineered to evoke fear, dread, and psychological unease."
                },
                {
                    name: "Mystery & Crime",
                    family: "suspense",
                    description: "Whodunits focused on solving puzzles, murders, and cases."
                },
                {
                    name: "Romance",
                    family: "character",
                    description: "Narratives tracking the development of romantic relationships."
                },
                {
                    name: "Science Fiction",
                    family: "speculative",
                    description: "Stories exploring advanced technology, space, and time travel."
                },
                {
                    name: "Thriller & Suspense",
                    family: "suspense",
                    description: "High-stakes plots designed to induce anxiety and excitement."
                },
                {
                    name: "Western",
                    family: "adventure",
                    description: "Tales set in the American frontier focusing on cowboys and outlaws."
                },
                {
                    name: "Biography & Memoir",
                    family: "life-writing",
                    description: "First-hand or thoroughly researched accounts of real lives."
                },
                {
                    name: "History",
                    family: "historical",
                    description: "Factual analysis of past cultures, wars, and civilizations."
                },
                {
                    name: "True Crime",
                    family: "suspense",
                    description: "Detailed journalism covering real-world criminal cases."
                },
                {
                    name: "Self-Help & Philosophy",
                    family: "insight",
                    description: "Texts offering personal development advice or life frameworks."
                }
            ];

        },


        renderGenreTypeDescriptions() {

            const rows =
                this.getStandardGenreTypeCatalog()
                    .map(
                        item => `
                            <li>
                                <strong>${this.escapeHTML(item.name)}</strong>: ${this.escapeHTML(item.description)}
                            </li>
                        `
                    )
                    .join("");

            return `
                <details class="project-genre-catalog">
                    <summary>Standard genre types</summary>
                    <ul class="project-genre-catalog-list">
                        ${rows}
                    </ul>
                </details>
            `;

        },


        renderProjectImagePicker() {

            const image =
                this.projectImageDraft;

            const hasImage =
                Boolean(image?.dataUrl);

            const imageLabel =
                hasImage
                    ? "Current project image preview"
                    : "No project image selected";

            const imagePreview =
                hasImage
                    ? `
                        <img
                            src="${this.escapeHTML(image.dataUrl)}"
                            alt="Project image preview"
                        >
                    `
                    : `
                        <span>
                            No image selected
                        </span>
                    `;

            return `
                <div class="project-image-picker">
                    <div
                        class="project-image-preview ${hasImage ? "has-image" : ""}"
                        aria-label="${imageLabel}"
                    >
                        ${imagePreview}
                    </div>

                    <div class="project-image-picker-actions">
                        <button
                            type="button"
                            class="button button-secondary"
                            data-action="choose-project-image"
                        >
                            ${hasImage ? "Change Image" : "Choose Image"}
                        </button>

                        <button
                            type="button"
                            class="button button-secondary"
                            data-action="remove-project-image"
                            ${hasImage ? "" : "disabled"}
                        >
                            Remove Image
                        </button>
                    </div>

                    <input
                        id="project-image-input"
                        class="visually-hidden"
                        type="file"
                        accept="image/jpeg,image/jpg,image/png,image/webp"
                        aria-label="Choose project image"
                    >
                </div>
            `;

        },


        parseGenreTags(value) {

            const source =
                Array.isArray(value)
                    ? value.map(item => String(item || "")).join(",")
                    : String(value || "");

            const seen =
                new Set();

            const tags =
                source
                    .split(",")
                    .map(
                        tag =>
                            this.normalizeGenreTag(
                                tag
                            )
                    )
                    .filter(Boolean)
                    .filter(tag => {
                        const key = tag.toLowerCase();

                        if (seen.has(key)) {
                            return false;
                        }

                        seen.add(key);
                        return true;
                    });

            return tags;

        },


        normalizeGenreTag(value) {

            return String(value || "")
                .replace(/\s+/g, " ")
                .trim();

        },


        getProjectGenreTags(project) {

            const fromTags =
                Array.isArray(project?.genreTags)
                    ? project.genreTags
                    : [];

            const fromPrimary =
                String(project?.genre || "").trim();

            return this.parseGenreTags([
                ...fromTags,
                fromPrimary
            ]);

        },


        getProjectGenreLabel(project) {

            const tags =
                this.getProjectGenreTags(
                    project
                );

            return tags.length
                ? tags.join(", ")
                : "Unspecified";

        },


        getGenreTagFamilyClass(tag) {

            const normalized =
                this
                    .normalizeGenreTag(tag)
                    .toLowerCase();

            const genreFamily =
                this.getStandardGenreTypeCatalog()
                    .find(
                        item =>
                            item.name.toLowerCase() === normalized
                    )
                    ?.family;

            return genreFamily
                ? `project-genre-chip-family-${genreFamily}`
                : "";

        },


        renderGenreFamilyLegend() {

            const items = [
                { family: "adventure", label: "Adventure" },
                { family: "humor", label: "Humor" },
                { family: "character", label: "Character" },
                { family: "speculative", label: "Speculative" },
                { family: "suspense", label: "Suspense" },
                { family: "historical", label: "Historical" },
                { family: "life-writing", label: "Life Writing" },
                { family: "insight", label: "Insight" },
                { family: "", label: "Custom" }
            ];

            const chips =
                items
                    .map(
                        item => `
                            <li>
                                <span class="project-genre-chip ${item.family ? `project-genre-chip-family-${item.family}` : ""}">
                                    ${this.escapeHTML(item.label)}
                                </span>
                            </li>
                        `
                    )
                    .join("");

            return `
                <div class="library-genre-legend-wrap" aria-label="Genre color legend">
                    <span class="library-genre-legend-label">Chip legend</span>
                    <ul class="library-genre-legend">
                        ${chips}
                    </ul>
                </div>
            `;

        },


        getUniqueGenreTags() {

            const tags = [];

            this.getProjects().forEach(
                project => {
                    this.getProjectGenreTags(project).forEach(
                        tag => tags.push(tag)
                    );
                }
            );

            return [
                ...new Set(tags)
            ].sort(
                (a, b) =>
                    a.localeCompare(
                        b,
                        undefined,
                        {
                            sensitivity: "base"
                        }
                    )
            );

        },


        renderProjectFormSelectOptions(
            options,
            selectedValue
        ) {

            const selected =
                String(
                    selectedValue || ""
                ).trim();


            return options
                .map(
                    option => {

                        const value =
                            String(
                                option || ""
                            ).trim();


                        if (!value) {

                            return "";

                        }


                        return `
                            <option
                                value="${this.escapeHTML(value)}"
                                ${value === selected ? "selected" : ""}
                            >
                                ${this.escapeHTML(value)}
                            </option>
                        `;

                    }
                )
                .join("");

        },


        getModalFormSignature(form) {

            if (!form) {

                return "";

            }


            const entries =
                Array.from(
                    new FormData(
                        form
                    ).entries()
                );


            return JSON.stringify(
                entries.map(
                    ([key, value]) => [
                        key,
                        typeof value === "string"
                            ? value
                            : String(
                                value
                            )
                    ]
                )
            );

        },


        setModalFormBaseline(form) {

            this.modalFormBaseline =
                this.getModalFormSignature(
                    form
                );

            this.modalFormDirty =
                false;

        },


        updateModalFormDirtyState(form) {

            if (
                this.modalFormBaseline === null
            ) {

                this.setModalFormBaseline(
                    form
                );

                return;

            }


            this.modalFormDirty =
                this.getModalFormSignature(
                    form
                ) !== this.modalFormBaseline;

        },


        captureProjectFormState(form) {

            if (!form) {
                return null;
            }

            const draft =
                this.getProjectFormDraft(
                    form
                );

            return {
                draft,
                baseline: this.modalFormBaseline,
                dirty: this.modalFormDirty
            };

        },


        getProjectFormDraft(form) {

            if (!form) {
                return null;
            }

            const fieldNames = [
                "name",
                "author",
                "genre",
                "type",
                "status",
                "series",
                "targetWords",
                "description"
            ];

            return fieldNames.reduce(
                (accumulator, name) => {

                    const field =
                        form.elements.namedItem(
                            name
                        );

                    if (
                        field &&
                        "value" in field
                    ) {
                        accumulator[name] =
                            String(field.value || "");
                    }

                    return accumulator;

                },
                {}
            );

        },


        applyProjectFormDraft(form, draft) {

            if (!form || !draft || typeof draft !== "object") {
                return;
            }

            Object.entries(draft).forEach(
                ([name, value]) => {

                    const field =
                        form.elements.namedItem(
                            name
                        );

                    if (
                        field &&
                        "value" in field
                    ) {
                        field.value =
                            String(value || "");
                    }

                }
            );

        },


        attemptCloseModal() {

            if (
                this.modalFormDirty &&
                !window.confirm(
                    "Discard unsaved changes?"
                )
            ) {

                return;

            }


            this.closeModal();

        },


        refreshProjectViews() {

            const route =
                this.core.state.get(
                    "app.currentView"
                );


            if (
                route ===
                "project-workspace"
            ) {

                this.renderProjectWorkspace(
                    this.container
                );

                return;

            }


            this.render(
                this.container
            );

        }

    };


})();