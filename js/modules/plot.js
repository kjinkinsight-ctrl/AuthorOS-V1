/*
=========================================================
AUTHOROS
PLOT STUDIO MODULE
Milestone 08
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSPlot = {

        name: "plot",

        core: null,

        container: null,

        modalContainer: null,

        selectedEntity: {
            type: "Overview",
            id: "overview"
        },

        activeProjectId: null,

        uiState: {
            search: "",
            entityType: "All",
            status: "All",
            arcId: "All",
            actId: "All",
            threadId: "All",
            characterId: "All",
            locationId: "All",
            sort: "updated-desc"
        },

        plotStatuses: [
            "Draft",
            "Developing",
            "Established",
            "Complete",
            "Archived"
        ],

        sceneStatuses: [
            "Planned",
            "Drafted",
            "Revised",
            "Complete"
        ],

        beatTypes: [
            "Opening",
            "Inciting Incident",
            "First Turning Point",
            "Midpoint",
            "Crisis",
            "Climax",
            "Resolution",
            "Custom"
        ],

        threadTypes: [
            "Main Plot",
            "Subplot",
            "Romance",
            "Mystery",
            "Political",
            "Character Arc",
            "Custom"
        ],

        initialize(core) {

            this.core = core;
            this.modalContainer = document.getElementById("modal-container");

            this.core.events.on("navigation:changed", navigation => {

                if (navigation?.route !== "plot") {
                    return;
                }

                if (this.container) {
                    this.render(this.container);
                }

            });

        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;

            const project = this.getActiveProject();

            if (!project) {
                container.innerHTML = this.renderMissingProjectState();
                this.bindMissingProjectEvents(container);
                return;
            }

            const hydrated = this.ensureProjectPlotShape(project);

            if (hydrated.changed) {
                this.persistProject(hydrated.project, "plot-hydrate");
            }

            const currentProject = this.getProjectById(project.id) || hydrated.project;
            this.activeProjectId = currentProject.id;

            const plot = this.getPlot(currentProject);
            const entities = this.getFlattenedEntities(currentProject, plot);

            if (!this.isSelectedEntityPresent(entities)) {
                this.selectedEntity = {
                    type: "Overview",
                    id: plot.overview.id
                };
            }

            const selected = this.getSelectedEntity(currentProject, plot, entities);
            const filtered = this.getFilteredEntities(currentProject, plot, entities);

            container.innerHTML = `
                <section class="plot-view library-view">

                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">PLOT STUDIO</p>
                            <h1>Plot Studio</h1>
                            <p class="library-description">
                                Plan structure, threads, beats, and scenes without changing manuscript text.
                            </p>
                            <p class="plot-project-context">
                                Project: ${this.escapeHTML(this.getProjectTitle(currentProject))}
                            </p>
                        </div>

                        <div class="library-actions plot-actions">
                            <button type="button" class="button button-primary" data-action="edit-plot-overview">
                                Edit Story Overview
                            </button>
                            <button type="button" class="button button-secondary" data-action="new-arc">+ Arc</button>
                            <button type="button" class="button button-secondary" data-action="new-act">+ Act</button>
                            <button type="button" class="button button-secondary" data-action="new-beat">+ Beat</button>
                            <button type="button" class="button button-secondary" data-action="new-thread">+ Thread</button>
                            <button type="button" class="button button-secondary" data-action="new-scene">+ Scene</button>
                        </div>
                    </header>

                    ${this.renderControls(currentProject, plot)}

                    <div class="library-results-bar">
                        <span class="library-count">
                            ${filtered.length}
                            ${filtered.length === 1 ? "Item" : "Items"}
                        </span>
                        ${
                            this.hasActiveFilters()
                                ? `
                                    <span class="library-filter-state">
                                        Filtered from ${entities.length} ${entities.length === 1 ? "item" : "items"}
                                    </span>
                                `
                                : ""
                        }
                    </div>

                    ${this.renderSummaryCards(plot)}

                    <div class="plot-layout ${selected ? "with-detail" : ""}">
                        <div class="plot-library-column">
                            ${
                                filtered.length
                                    ? this.renderEntityGrid(currentProject, plot, filtered)
                                    : this.renderEmptyState(entities.length > 0)
                            }
                        </div>

                        <aside class="plot-detail-column" aria-label="Plot detail panel">
                            ${selected ? this.renderDetail(currentProject, plot, selected) : this.renderDetailEmptyState()}
                        </aside>
                    </div>

                </section>
            `;

            this.bindEvents(container, currentProject.id, plot);

        },


        renderMissingProjectState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">◇</div>
                    <p class="eyebrow">PLOT STUDIO</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to manage plot planning.</p>
                    <div class="manuscript-missing-actions">
                        <button type="button" class="button button-primary" data-action="open-story-library">
                            Open Story Library
                        </button>
                    </div>
                </section>
            `;

        },


        bindMissingProjectEvents(container) {

            container
                .querySelector('[data-action="open-story-library"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("projects");
                });

        },


        getActiveProject() {

            const fromState = this.core.state.get("currentProject");

            if (fromState && typeof fromState === "object") {
                return fromState;
            }

            const activeProjectId = this.core.storage.loadActiveProjectId();

            if (!activeProjectId) {
                return null;
            }

            return this.getProjectById(activeProjectId);

        },


        getProjectById(projectId) {

            const projects = this.core.state.get("projects");

            if (!Array.isArray(projects)) {
                return null;
            }

            return projects.find(project => project.id === projectId) || null;

        },


        getProjectTitle(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        },


        ensureProjectPlotShape(project) {

            const next = this.cloneData(project);

            if (!next) {
                return { project, changed: false };
            }

            let changed = false;

            if (!next.story || typeof next.story !== "object") {
                next.story = {};
                changed = true;
            }

            if (!next.story.plot || typeof next.story.plot !== "object") {
                next.story.plot = {};
                changed = true;
            }

            const now = new Date().toISOString();

            const defaultOverview = {
                id: AuthorOSHelpers.generateId("plot_overview"),
                projectId: next.id,
                title: this.getProjectTitle(next),
                premise: "",
                centralConflict: "",
                stakes: "",
                theme: "",
                synopsis: "",
                ending: "",
                notes: "",
                createdAt: now,
                updatedAt: now
            };

            if (!next.story.plot.overview || typeof next.story.plot.overview !== "object") {
                next.story.plot.overview = defaultOverview;
                changed = true;
            }

            const normalizedOverview = this.normalizeOverview(next.story.plot.overview, next.id, this.getProjectTitle(next));

            if (JSON.stringify(next.story.plot.overview) !== JSON.stringify(normalizedOverview)) {
                next.story.plot.overview = normalizedOverview;
                changed = true;
            }

            changed = this.ensureEntityCollection(next.story.plot, "arcs", next.id, this.normalizeArc.bind(this)) || changed;
            changed = this.ensureEntityCollection(next.story.plot, "acts", next.id, this.normalizeAct.bind(this)) || changed;
            changed = this.ensureEntityCollection(next.story.plot, "beats", next.id, this.normalizeBeat.bind(this)) || changed;
            changed = this.ensureEntityCollection(next.story.plot, "threads", next.id, this.normalizeThread.bind(this)) || changed;
            changed = this.ensureEntityCollection(next.story.plot, "scenes", next.id, this.normalizeScene.bind(this)) || changed;

            if (!next.statistics || typeof next.statistics !== "object") {
                next.statistics = {};
                changed = true;
            }

            const sceneCount = next.story.plot.scenes.length;

            if (Number(next.statistics.plotScenes || 0) !== sceneCount) {
                next.statistics.plotScenes = sceneCount;
                changed = true;
            }

            const activeSceneCount = next.story.plot.scenes.filter(scene => scene.status !== "Archived").length;

            if (Number(next.statistics.plot || 0) !== activeSceneCount) {
                next.statistics.plot = activeSceneCount;
                changed = true;
            }

            return {
                project: next,
                changed
            };

        },


        ensureEntityCollection(plot, key, projectId, normalizer) {

            if (!Array.isArray(plot[key])) {
                plot[key] = [];
                return true;
            }

            let changed = false;
            const seen = new Set();

            const normalized = plot[key]
                .map(candidate => {

                    const item = normalizer(candidate, projectId);

                    if (!item) {
                        changed = true;
                        return null;
                    }

                    if (JSON.stringify(candidate) !== JSON.stringify(item)) {
                        changed = true;
                    }

                    return item;

                })
                .filter(Boolean)
                .sort((a, b) => Number(a.order || 0) - Number(b.order || 0))
                .map((item, index) => {

                    let nextItem = {
                        ...item,
                        order: index + 1
                    };

                    if (seen.has(nextItem.id)) {
                        nextItem.id = AuthorOSHelpers.generateId(key.slice(0, -1));
                        changed = true;
                    }

                    seen.add(nextItem.id);

                    if (Number(item.order || 0) !== index + 1) {
                        changed = true;
                    }

                    return nextItem;

                });

            plot[key] = normalized;

            return changed;

        },


        normalizeOverview(candidate, projectId, projectTitle) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();

            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("plot_overview"),
                projectId,
                title: String(candidate.title || projectTitle || "Story Overview").trim() || "Story Overview",
                premise: String(candidate.premise || ""),
                centralConflict: String(candidate.centralConflict || ""),
                stakes: String(candidate.stakes || ""),
                theme: String(candidate.theme || ""),
                synopsis: String(candidate.synopsis || ""),
                ending: String(candidate.ending || ""),
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt
            };

        },


        normalizeArc(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();
            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const status = this.isAllowedPlotStatus(candidate.status)
                ? String(candidate.status).trim()
                : "Draft";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("arc"),
                projectId,
                title: String(candidate.title || "").trim() || "Untitled Arc",
                summary: String(candidate.summary || ""),
                purpose: String(candidate.purpose || ""),
                status,
                order: this.normalizeOrder(candidate.order),
                notes: String(candidate.notes || ""),
                beginning: String(candidate.beginning || ""),
                midpoint: String(candidate.midpoint || ""),
                ending: String(candidate.ending || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeAct(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();
            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("act"),
                projectId,
                title: String(candidate.title || "").trim() || "Untitled Act",
                summary: String(candidate.summary || ""),
                order: this.normalizeOrder(candidate.order),
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt
            };

        },


        normalizeBeat(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();
            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const status = this.isAllowedPlotStatus(candidate.status)
                ? String(candidate.status).trim()
                : "Draft";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            const threadIds = Array.isArray(candidate.threadIds)
                ? candidate.threadIds
                    .map(id => String(id || "").trim())
                    .filter(Boolean)
                : [];

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("beat"),
                projectId,
                arcId: String(candidate.arcId || "").trim(),
                actId: String(candidate.actId || "").trim(),
                threadIds,
                title: String(candidate.title || "").trim() || "Untitled Beat",
                description: String(candidate.description || ""),
                type: String(candidate.type || "Custom").trim() || "Custom",
                order: this.normalizeOrder(candidate.order),
                status,
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeThread(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();
            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const status = this.isAllowedPlotStatus(candidate.status)
                ? String(candidate.status).trim()
                : "Draft";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            const references = Array.isArray(candidate.references)
                ? candidate.references
                    .map(reference => this.normalizeReference(reference, projectId, candidate.id))
                    .filter(Boolean)
                : [];

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("thread"),
                projectId,
                title: String(candidate.title || "").trim() || "Untitled Thread",
                summary: String(candidate.summary || ""),
                type: String(candidate.type || "Subplot").trim() || "Subplot",
                status,
                order: this.normalizeOrder(candidate.order),
                notes: String(candidate.notes || ""),
                references,
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeScene(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();
            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const status = this.isAllowedSceneStatus(candidate.status)
                ? String(candidate.status).trim()
                : "Planned";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            const threadIds = Array.isArray(candidate.threadIds)
                ? candidate.threadIds
                    .map(id => String(id || "").trim())
                    .filter(Boolean)
                : [];

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("scene"),
                projectId,
                chapterId: String(candidate.chapterId || "").trim(),
                arcId: String(candidate.arcId || "").trim(),
                actId: String(candidate.actId || "").trim(),
                threadIds,
                title: String(candidate.title || "").trim() || "Untitled Scene",
                summary: String(candidate.summary || ""),
                goal: String(candidate.goal || ""),
                conflict: String(candidate.conflict || ""),
                outcome: String(candidate.outcome || ""),
                povCharacterId: String(candidate.povCharacterId || "").trim(),
                locationId: String(candidate.locationId || "").trim(),
                time: String(candidate.time || ""),
                status,
                order: this.normalizeOrder(candidate.order),
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeReference(reference, projectId, sourceId) {

            if (!reference || typeof reference !== "object") {
                return null;
            }

            const targetKind = String(reference.targetKind || "").trim().toLowerCase();
            const allowedKinds = ["arc", "beat", "scene", "character", "world", "chapter", "thread", "act"];

            if (!allowedKinds.includes(targetKind)) {
                return null;
            }

            const targetId = String(reference.targetId || reference.targetEntryId || "").trim();

            if (!targetId) {
                return null;
            }

            const normalizedProjectId = typeof reference.projectId === "string" && reference.projectId.trim()
                ? reference.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            return {
                sourceId: String(reference.sourceId || sourceId || "").trim(),
                targetKind,
                targetId,
                relationshipType: String(reference.relationshipType || "Related").trim() || "Related",
                description: String(reference.description || ""),
                projectId
            };

        },


        normalizeDateValue(value, fallback) {

            if (value === null || value === undefined || value === "") {
                return fallback;
            }

            const date = new Date(value);

            if (Number.isNaN(date.getTime())) {
                return fallback;
            }

            return date.toISOString();

        },


        normalizeOrder(order) {

            const value = Number(order);

            if (!Number.isFinite(value) || value < 1) {
                return 1;
            }

            return Math.trunc(value);

        },


        getPlot(project) {

            const fallback = {
                overview: this.normalizeOverview({ title: this.getProjectTitle(project) }, project.id, this.getProjectTitle(project)),
                arcs: [],
                acts: [],
                beats: [],
                threads: [],
                scenes: []
            };

            if (!project?.story?.plot || typeof project.story.plot !== "object") {
                return fallback;
            }

            return project.story.plot;

        },


        getFlattenedEntities(project, plot) {

            const entities = [];

            entities.push({
                entityType: "Overview",
                id: plot.overview.id,
                title: plot.overview.title || "Story Overview",
                summary: plot.overview.synopsis || plot.overview.premise || "No overview yet.",
                status: "",
                order: 0,
                updatedAt: plot.overview.updatedAt,
                createdAt: plot.overview.createdAt,
                data: plot.overview
            });

            plot.arcs.forEach(arc => {
                entities.push({
                    entityType: "Arc",
                    id: arc.id,
                    title: arc.title,
                    summary: arc.summary,
                    status: arc.status,
                    order: arc.order,
                    updatedAt: arc.updatedAt,
                    createdAt: arc.createdAt,
                    data: arc
                });
            });

            plot.acts.forEach(act => {
                entities.push({
                    entityType: "Act",
                    id: act.id,
                    title: act.title,
                    summary: act.summary,
                    status: "",
                    order: act.order,
                    updatedAt: act.updatedAt,
                    createdAt: act.createdAt,
                    data: act
                });
            });

            plot.beats.forEach(beat => {
                entities.push({
                    entityType: "Beat",
                    id: beat.id,
                    title: beat.title,
                    summary: beat.description,
                    status: beat.status,
                    order: beat.order,
                    updatedAt: beat.updatedAt,
                    createdAt: beat.createdAt,
                    data: beat
                });
            });

            plot.threads.forEach(thread => {
                entities.push({
                    entityType: "Thread",
                    id: thread.id,
                    title: thread.title,
                    summary: thread.summary,
                    status: thread.status,
                    order: thread.order,
                    updatedAt: thread.updatedAt,
                    createdAt: thread.createdAt,
                    data: thread
                });
            });

            plot.scenes.forEach(scene => {
                entities.push({
                    entityType: "Scene",
                    id: scene.id,
                    title: scene.title,
                    summary: scene.summary,
                    status: scene.status,
                    order: scene.order,
                    updatedAt: scene.updatedAt,
                    createdAt: scene.createdAt,
                    data: scene
                });
            });

            return entities;

        },


        isSelectedEntityPresent(entities) {

            if (!this.selectedEntity?.id || !this.selectedEntity?.type) {
                return false;
            }

            return entities.some(item => item.id === this.selectedEntity.id && item.entityType === this.selectedEntity.type);

        },


        getSelectedEntity(project, plot, entities) {

            return entities.find(
                item =>
                    item.id === this.selectedEntity.id &&
                    item.entityType === this.selectedEntity.type
            ) || null;

        },


        renderControls(project, plot) {

            const arcs = plot.arcs;
            const acts = plot.acts;
            const threads = plot.threads;
            const characters = this.getProjectCharacters(project);
            const locations = this.getProjectLocations(project);

            return `
                <div class="library-controls plot-controls">

                    <div class="library-search">
                        <label for="plot-search-input" class="visually-hidden">Search plot</label>
                        <span class="library-search-icon" aria-hidden="true">⌕</span>
                        <input
                            id="plot-search-input"
                            type="search"
                            class="library-search-input"
                            placeholder="Search plot..."
                            autocomplete="off"
                            value="${this.escapeHTML(this.uiState.search)}"
                        />
                        ${
                            this.uiState.search
                                ? `
                                    <button type="button" class="library-search-clear" data-action="clear-plot-search" aria-label="Clear search">×</button>
                                `
                                : ""
                        }
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-entity-filter">Entity</label>
                        <select id="plot-entity-filter" class="library-filter-select">
                            ${["All", "Overview", "Arc", "Act", "Beat", "Thread", "Scene"].map(value => `
                                <option value="${this.escapeHTML(value)}" ${this.uiState.entityType === value ? "selected" : ""}>${this.escapeHTML(value)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-status-filter">Status</label>
                        <select id="plot-status-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.status === "All" ? "selected" : ""}>All statuses</option>
                            ${[...this.plotStatuses, ...this.sceneStatuses]
                                .filter((item, index, list) => list.indexOf(item) === index)
                                .map(value => `
                                    <option value="${this.escapeHTML(value)}" ${this.uiState.status === value ? "selected" : ""}>${this.escapeHTML(value)}</option>
                                `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-arc-filter">Arc</label>
                        <select id="plot-arc-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.arcId === "All" ? "selected" : ""}>All arcs</option>
                            ${arcs.map(arc => `
                                <option value="${this.escapeHTML(arc.id)}" ${this.uiState.arcId === arc.id ? "selected" : ""}>${this.escapeHTML(arc.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-act-filter">Act</label>
                        <select id="plot-act-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.actId === "All" ? "selected" : ""}>All acts</option>
                            ${acts.map(act => `
                                <option value="${this.escapeHTML(act.id)}" ${this.uiState.actId === act.id ? "selected" : ""}>${this.escapeHTML(act.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-thread-filter">Thread</label>
                        <select id="plot-thread-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.threadId === "All" ? "selected" : ""}>All threads</option>
                            ${threads.map(thread => `
                                <option value="${this.escapeHTML(thread.id)}" ${this.uiState.threadId === thread.id ? "selected" : ""}>${this.escapeHTML(thread.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-character-filter">Character</label>
                        <select id="plot-character-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.characterId === "All" ? "selected" : ""}>All characters</option>
                            ${characters.map(character => `
                                <option value="${this.escapeHTML(character.id)}" ${this.uiState.characterId === character.id ? "selected" : ""}>${this.escapeHTML(this.getCharacterName(character))}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-location-filter">Location</label>
                        <select id="plot-location-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.locationId === "All" ? "selected" : ""}>All locations</option>
                            ${locations.map(location => `
                                <option value="${this.escapeHTML(location.id)}" ${this.uiState.locationId === location.id ? "selected" : ""}>${this.escapeHTML(location.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="plot-sort-filter">Sort</label>
                        <select id="plot-sort-filter" class="library-filter-select">
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently created</option>
                            <option value="title-asc" ${this.uiState.sort === "title-asc" ? "selected" : ""}>Title A-Z</option>
                            <option value="title-desc" ${this.uiState.sort === "title-desc" ? "selected" : ""}>Title Z-A</option>
                            <option value="order-asc" ${this.uiState.sort === "order-asc" ? "selected" : ""}>Order</option>
                        </select>
                    </div>

                    ${
                        this.hasActiveFilters()
                            ? `
                                <button type="button" class="library-clear-filters" data-action="clear-plot-filters">Clear filters</button>
                            `
                            : ""
                    }

                </div>
            `;

        },


        renderSummaryCards(plot) {

            const totalScenes = plot.scenes.length;
            const planned = plot.scenes.filter(scene => scene.status === "Planned").length;
            const complete = plot.scenes.filter(scene => scene.status === "Complete").length;

            return `
                <section class="plot-summary-grid" aria-label="Plot planning summary">
                    <article class="plot-summary-card">
                        <h3>Arcs</h3>
                        <p>${plot.arcs.length}</p>
                    </article>
                    <article class="plot-summary-card">
                        <h3>Acts</h3>
                        <p>${plot.acts.length}</p>
                    </article>
                    <article class="plot-summary-card">
                        <h3>Beats</h3>
                        <p>${plot.beats.length}</p>
                    </article>
                    <article class="plot-summary-card">
                        <h3>Threads</h3>
                        <p>${plot.threads.length}</p>
                    </article>
                    <article class="plot-summary-card">
                        <h3>Scenes</h3>
                        <p>${totalScenes}</p>
                    </article>
                    <article class="plot-summary-card">
                        <h3>Progress</h3>
                        <p>${complete}/${totalScenes || 0} complete</p>
                        <small>${planned} planned</small>
                    </article>
                </section>
            `;

        },


        hasActiveFilters() {

            return Boolean(
                this.uiState.search.trim() ||
                this.uiState.entityType !== "All" ||
                this.uiState.status !== "All" ||
                this.uiState.arcId !== "All" ||
                this.uiState.actId !== "All" ||
                this.uiState.threadId !== "All" ||
                this.uiState.characterId !== "All" ||
                this.uiState.locationId !== "All" ||
                this.uiState.sort !== "updated-desc"
            );

        },


        clearFilters() {

            this.uiState = {
                search: "",
                entityType: "All",
                status: "All",
                arcId: "All",
                actId: "All",
                threadId: "All",
                characterId: "All",
                locationId: "All",
                sort: "updated-desc"
            };

            this.render(this.container);

        },


        getFilteredEntities(project, plot, entities) {

            let filtered = [...entities];

            if (this.uiState.entityType !== "All") {
                filtered = filtered.filter(item => item.entityType === this.uiState.entityType);
            }

            if (this.uiState.status !== "All") {
                filtered = filtered.filter(item => String(item.status || "") === this.uiState.status);
            }

            if (this.uiState.arcId !== "All") {
                filtered = filtered.filter(item => {

                    if (item.entityType === "Beat" || item.entityType === "Scene") {
                        return String(item.data.arcId || "") === this.uiState.arcId;
                    }

                    if (item.entityType === "Arc") {
                        return item.id === this.uiState.arcId;
                    }

                    return false;

                });
            }

            if (this.uiState.actId !== "All") {
                filtered = filtered.filter(item => {

                    if (item.entityType === "Beat" || item.entityType === "Scene") {
                        return String(item.data.actId || "") === this.uiState.actId;
                    }

                    if (item.entityType === "Act") {
                        return item.id === this.uiState.actId;
                    }

                    return false;

                });
            }

            if (this.uiState.threadId !== "All") {
                filtered = filtered.filter(item => {

                    if (item.entityType === "Thread") {
                        return item.id === this.uiState.threadId;
                    }

                    if (item.entityType === "Beat" || item.entityType === "Scene") {
                        return Array.isArray(item.data.threadIds) && item.data.threadIds.includes(this.uiState.threadId);
                    }

                    return false;

                });
            }

            if (this.uiState.characterId !== "All") {
                filtered = filtered.filter(item => {

                    if (item.entityType === "Scene") {
                        return String(item.data.povCharacterId || "") === this.uiState.characterId;
                    }

                    if (item.entityType === "Thread") {
                        return Array.isArray(item.data.references) && item.data.references.some(reference =>
                            reference.targetKind === "character" && reference.targetId === this.uiState.characterId
                        );
                    }

                    return false;

                });
            }

            if (this.uiState.locationId !== "All") {
                filtered = filtered.filter(item => {

                    if (item.entityType === "Scene") {
                        return String(item.data.locationId || "") === this.uiState.locationId;
                    }

                    if (item.entityType === "Thread") {
                        return Array.isArray(item.data.references) && item.data.references.some(reference =>
                            reference.targetKind === "world" && reference.targetId === this.uiState.locationId
                        );
                    }

                    return false;

                });
            }

            const search = this.uiState.search.trim().toLowerCase();

            if (search) {
                filtered = filtered.filter(item => {

                    const entry = item.data || {};

                    const searchable = [
                        item.entityType,
                        item.title,
                        item.summary,
                        entry.premise,
                        entry.centralConflict,
                        entry.stakes,
                        entry.theme,
                        entry.synopsis,
                        entry.ending,
                        entry.notes,
                        entry.description,
                        entry.goal,
                        entry.conflict,
                        entry.outcome,
                        entry.type,
                        entry.purpose,
                        entry.summary,
                        entry.time,
                        Array.isArray(entry.threadIds) ? entry.threadIds.join(" ") : "",
                        Array.isArray(entry.references)
                            ? entry.references.map(reference => `${reference.targetKind} ${reference.relationshipType} ${reference.description}`).join(" ")
                            : ""
                    ]
                        .filter(value => value !== null && value !== undefined)
                        .join(" ")
                        .toLowerCase();

                    return searchable.includes(search);

                });
            }

            return this.sortEntities(filtered);

        },


        sortEntities(entities) {

            const results = [...entities];

            const dateValue = value => {
                const time = Date.parse(value || "");
                return Number.isNaN(time) ? 0 : time;
            };

            switch (this.uiState.sort) {

                case "created-desc":
                    return results.sort((left, right) => dateValue(right.createdAt) - dateValue(left.createdAt));

                case "title-asc":
                    return results.sort((left, right) =>
                        this.getEntityTitle(left).localeCompare(this.getEntityTitle(right), undefined, { sensitivity: "base" })
                    );

                case "title-desc":
                    return results.sort((left, right) =>
                        this.getEntityTitle(right).localeCompare(this.getEntityTitle(left), undefined, { sensitivity: "base" })
                    );

                case "order-asc":
                    return results.sort((left, right) => {
                        const leftOrder = Number(left.order || 0);
                        const rightOrder = Number(right.order || 0);

                        if (leftOrder !== rightOrder) {
                            return leftOrder - rightOrder;
                        }

                        return dateValue(right.updatedAt) - dateValue(left.updatedAt);
                    });

                case "updated-desc":
                default:
                    return results.sort((left, right) => dateValue(right.updatedAt) - dateValue(left.updatedAt));

            }

        },


        renderEntityGrid(project, plot, entities) {

            return `
                <div class="project-grid plot-grid">
                    ${entities.map(item => this.renderEntityCard(project, plot, item)).join("")}
                </div>
            `;

        },


        renderEntityCard(project, plot, item) {

            const selected =
                this.selectedEntity.id === item.id &&
                this.selectedEntity.type === item.entityType;

            const title = this.getEntityTitle(item);
            const status = String(item.status || "").trim();
            const summary = String(item.summary || "").trim() || "No summary yet.";

            const canDuplicate = ["Arc", "Beat", "Thread", "Scene"].includes(item.entityType);
            const canArchive = ["Arc", "Beat", "Thread", "Scene"].includes(item.entityType);
            const canDelete = item.entityType !== "Overview";
            const canReorder = ["Arc", "Act", "Beat", "Thread", "Scene"].includes(item.entityType);

            return `
                <article class="project-card plot-card ${selected ? "selected" : ""}">
                    <div class="project-card-body">
                        <header class="plot-card-header">
                            <h2>${this.escapeHTML(title)}</h2>
                            <p class="plot-card-updated">Updated ${this.escapeHTML(this.formatDate(item.updatedAt))}</p>
                        </header>

                        <dl class="plot-card-meta">
                            <div>
                                <dt>Entity</dt>
                                <dd>${this.escapeHTML(item.entityType)}</dd>
                            </div>
                            <div>
                                <dt>Status</dt>
                                <dd>${this.escapeHTML(status || "-")}</dd>
                            </div>
                            <div>
                                <dt>Order</dt>
                                <dd>${this.escapeHTML(item.order ? String(item.order) : "-")}</dd>
                            </div>
                        </dl>

                        <p class="plot-card-summary">${this.escapeHTML(summary)}</p>

                        <div class="idea-card-actions">
                            <button type="button" class="button button-secondary" data-action="open-plot-entity" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Open</button>
                            <button type="button" class="button button-secondary" data-action="edit-plot-entity" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Edit</button>
                            ${
                                canDuplicate
                                    ? `<button type="button" class="button button-secondary" data-action="duplicate-plot-entity" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Duplicate</button>`
                                    : ""
                            }
                            ${
                                canReorder
                                    ? `
                                        <button type="button" class="button button-secondary" data-action="move-plot-entity-up" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Move Up</button>
                                        <button type="button" class="button button-secondary" data-action="move-plot-entity-down" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Move Down</button>
                                    `
                                    : ""
                            }
                            ${
                                canArchive
                                    ? status === "Archived"
                                        ? `<button type="button" class="button button-secondary" data-action="restore-plot-entity" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Restore</button>`
                                        : `<button type="button" class="button button-secondary" data-action="archive-plot-entity" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Archive</button>`
                                    : ""
                            }
                            ${
                                canDelete
                                    ? `<button type="button" class="button button-danger" data-action="delete-plot-entity" data-entity-type="${this.escapeHTML(item.entityType)}" data-entity-id="${this.escapeHTML(item.id)}">Delete</button>`
                                    : ""
                            }
                        </div>
                    </div>
                </article>
            `;

        },


        renderEmptyState(hasData) {

            if (hasData) {
                return `
                    <section class="library-empty-state">
                        <div class="empty-state-icon">⌕</div>
                        <h2>No plot items match your filters</h2>
                        <p>Adjust search, filters, or sorting.</p>
                        <button type="button" class="button button-secondary" data-action="clear-plot-filters">Clear filters</button>
                    </section>
                `;
            }

            return `
                <section class="library-empty-state">
                    <div class="empty-state-icon">◆</div>
                    <h2>No plot data yet</h2>
                    <p>Start with a story overview, then add arcs, acts, beats, threads, and scenes.</p>
                    <button type="button" class="button button-primary" data-action="edit-plot-overview">Add Story Overview</button>
                </section>
            `;

        },


        renderDetailEmptyState() {

            return `
                <section class="idea-detail-empty-state">
                    <h3>Select a plot item</h3>
                    <p>Open a card to view and manage plot details.</p>
                </section>
            `;

        },


        renderDetail(project, plot, selected) {

            switch (selected.entityType) {

                case "Overview":
                    return this.renderOverviewDetail(selected.data);

                case "Arc":
                    return this.renderArcDetail(selected.data);

                case "Act":
                    return this.renderActDetail(selected.data);

                case "Beat":
                    return this.renderBeatDetail(plot, selected.data);

                case "Thread":
                    return this.renderThreadDetail(project, plot, selected.data);

                case "Scene":
                    return this.renderSceneDetail(project, plot, selected.data);

                default:
                    return this.renderDetailEmptyState();

            }

        },


        renderOverviewDetail(overview) {

            return `
                <article class="idea-detail-card plot-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">PLOT OVERVIEW</p>
                        <h2>${this.escapeHTML(overview.title || "Story Overview")}</h2>
                    </header>

                    <dl class="idea-detail-meta">
                        <div>
                            <dt>Created</dt>
                            <dd>${this.escapeHTML(this.formatDate(overview.createdAt))}</dd>
                        </div>
                        <div>
                            <dt>Updated</dt>
                            <dd>${this.escapeHTML(this.formatDate(overview.updatedAt))}</dd>
                        </div>
                    </dl>

                    ${this.renderDetailTextBlock("Premise", overview.premise)}
                    ${this.renderDetailTextBlock("Central Conflict", overview.centralConflict)}
                    ${this.renderDetailTextBlock("Stakes", overview.stakes)}
                    ${this.renderDetailTextBlock("Theme", overview.theme)}
                    ${this.renderDetailTextBlock("Synopsis", overview.synopsis)}
                    ${this.renderDetailTextBlock("Ending", overview.ending)}
                    ${this.renderDetailTextBlock("Notes", overview.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-plot-overview">Edit Overview</button>
                    </div>
                </article>
            `;

        },


        renderArcDetail(arc) {

            return `
                <article class="idea-detail-card plot-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">PLOT ARC</p>
                        <h2>${this.escapeHTML(arc.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(arc.status || "Draft")}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(arc.order || 1))}</dd></div>
                        <div><dt>Created</dt><dd>${this.escapeHTML(this.formatDate(arc.createdAt))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(arc.updatedAt))}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Summary", arc.summary)}
                    ${this.renderDetailTextBlock("Purpose", arc.purpose)}
                    ${this.renderDetailTextBlock("Beginning", arc.beginning)}
                    ${this.renderDetailTextBlock("Midpoint", arc.midpoint)}
                    ${this.renderDetailTextBlock("Ending", arc.ending)}
                    ${this.renderDetailTextBlock("Notes", arc.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-plot-entity" data-entity-type="Arc" data-entity-id="${this.escapeHTML(arc.id)}">Edit</button>
                    </div>
                </article>
            `;

        },


        renderActDetail(act) {

            return `
                <article class="idea-detail-card plot-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">PLOT ACT</p>
                        <h2>${this.escapeHTML(act.title)}</h2>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(act.order || 1))}</dd></div>
                        <div><dt>Created</dt><dd>${this.escapeHTML(this.formatDate(act.createdAt))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(act.updatedAt))}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Summary", act.summary)}
                    ${this.renderDetailTextBlock("Notes", act.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-plot-entity" data-entity-type="Act" data-entity-id="${this.escapeHTML(act.id)}">Edit</button>
                    </div>
                </article>
            `;

        },


        renderBeatDetail(plot, beat) {

            const arc = plot.arcs.find(item => item.id === beat.arcId);
            const act = plot.acts.find(item => item.id === beat.actId);
            const threadLabels = this.resolveThreadLabels(plot, beat.threadIds);

            return `
                <article class="idea-detail-card plot-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">PLOT BEAT</p>
                        <h2>${this.escapeHTML(beat.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(beat.type || "Custom")} | ${this.escapeHTML(beat.status || "Draft")}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(beat.order || 1))}</dd></div>
                        <div><dt>Arc</dt><dd>${this.escapeHTML(arc ? arc.title : beat.arcId ? "Missing arc reference" : "Unlinked")}</dd></div>
                        <div><dt>Act</dt><dd>${this.escapeHTML(act ? act.title : beat.actId ? "Missing act reference" : "Unlinked")}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Description", beat.description)}
                    ${this.renderDetailTextBlock("Threads", threadLabels.length ? threadLabels.join(", ") : "Not linked")}
                    ${this.renderDetailTextBlock("Notes", beat.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-plot-entity" data-entity-type="Beat" data-entity-id="${this.escapeHTML(beat.id)}">Edit</button>
                    </div>
                </article>
            `;

        },


        renderThreadDetail(project, plot, thread) {

            const references = this.resolveReferences(project, plot, thread.references || []);

            return `
                <article class="idea-detail-card plot-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">PLOT THREAD</p>
                        <h2>${this.escapeHTML(thread.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(thread.type || "Subplot")} | ${this.escapeHTML(thread.status || "Draft")}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(thread.order || 1))}</dd></div>
                        <div><dt>Created</dt><dd>${this.escapeHTML(this.formatDate(thread.createdAt))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(thread.updatedAt))}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Summary", thread.summary)}
                    ${this.renderDetailTextBlock("Notes", thread.notes)}

                    <section class="idea-detail-section">
                        <h3>References</h3>
                        ${
                            references.length
                                ? `
                                    <ul class="plot-reference-list">
                                        ${references.map((reference, index) => `
                                            <li>
                                                <div class="plot-reference-item-main">
                                                    <strong>${this.escapeHTML(reference.relationshipType)}</strong>
                                                    <p>${this.escapeHTML(reference.targetLabel)}</p>
                                                    <p>${this.escapeHTML(reference.description || "No description.")}</p>
                                                </div>
                                                <div class="plot-reference-item-actions">
                                                    <button type="button" class="button button-secondary" data-action="edit-thread-reference" data-thread-id="${this.escapeHTML(thread.id)}" data-reference-index="${index}">Edit</button>
                                                    <button type="button" class="button button-danger" data-action="remove-thread-reference" data-thread-id="${this.escapeHTML(thread.id)}" data-reference-index="${index}">Remove</button>
                                                </div>
                                            </li>
                                        `).join("")}
                                    </ul>
                                `
                                : "<p>No references added.</p>"
                        }
                        <button type="button" class="button button-secondary" data-action="add-thread-reference" data-thread-id="${this.escapeHTML(thread.id)}">Add Reference</button>
                    </section>

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-plot-entity" data-entity-type="Thread" data-entity-id="${this.escapeHTML(thread.id)}">Edit</button>
                    </div>
                </article>
            `;

        },


        renderSceneDetail(project, plot, scene) {

            const character = this.getCharacterById(project, scene.povCharacterId);
            const location = this.getWorldEntryById(project, scene.locationId);
            const chapter = this.getChapterById(project, scene.chapterId);
            const arc = plot.arcs.find(item => item.id === scene.arcId);
            const act = plot.acts.find(item => item.id === scene.actId);
            const threadLabels = this.resolveThreadLabels(plot, scene.threadIds);

            return `
                <article class="idea-detail-card plot-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">PLOT SCENE</p>
                        <h2>${this.escapeHTML(scene.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(scene.status || "Planned")}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(scene.order || 1))}</dd></div>
                        <div><dt>POV</dt><dd>${this.escapeHTML(character ? this.getCharacterName(character) : scene.povCharacterId ? "Missing character reference" : "Unassigned")}</dd></div>
                        <div><dt>Location</dt><dd>${this.escapeHTML(location ? location.title : scene.locationId ? "Missing world reference" : "Unassigned")}</dd></div>
                    </dl>

                    <dl class="idea-detail-meta">
                        <div><dt>Arc</dt><dd>${this.escapeHTML(arc ? arc.title : scene.arcId ? "Missing arc reference" : "Unlinked")}</dd></div>
                        <div><dt>Act</dt><dd>${this.escapeHTML(act ? act.title : scene.actId ? "Missing act reference" : "Unlinked")}</dd></div>
                        <div><dt>Chapter</dt><dd>${this.escapeHTML(chapter ? chapter.title : scene.chapterId ? "Missing chapter reference" : "Unlinked")}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Summary", scene.summary)}
                    ${this.renderDetailTextBlock("Goal", scene.goal)}
                    ${this.renderDetailTextBlock("Conflict", scene.conflict)}
                    ${this.renderDetailTextBlock("Outcome", scene.outcome)}
                    ${this.renderDetailTextBlock("Time", scene.time)}
                    ${this.renderDetailTextBlock("Threads", threadLabels.length ? threadLabels.join(", ") : "Not linked")}
                    ${this.renderDetailTextBlock("Notes", scene.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-plot-entity" data-entity-type="Scene" data-entity-id="${this.escapeHTML(scene.id)}">Edit</button>
                        ${
                            scene.chapterId
                                ? `<button type="button" class="button button-secondary" data-action="open-scene-chapter" data-chapter-id="${this.escapeHTML(scene.chapterId)}">Open Chapter</button>`
                                : ""
                        }
                        ${
                            scene.povCharacterId
                                ? `<button type="button" class="button button-secondary" data-action="open-scene-character" data-character-id="${this.escapeHTML(scene.povCharacterId)}">Open Character</button>`
                                : ""
                        }
                        ${
                            scene.locationId
                                ? `<button type="button" class="button button-secondary" data-action="open-scene-world" data-world-id="${this.escapeHTML(scene.locationId)}">Open World Entry</button>`
                                : ""
                        }
                    </div>
                </article>
            `;

        },


        renderDetailTextBlock(label, value) {

            const text = String(value || "").trim();

            return `
                <section class="idea-detail-section">
                    <h3>${this.escapeHTML(label)}</h3>
                    <p>${text ? this.escapeHTML(text) : "Not provided."}</p>
                </section>
            `;

        },


        bindEvents(container, projectId, plot) {

            container.querySelector('[data-action="edit-plot-overview"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showOverviewModal(projectId);
            });

            container.querySelector('[data-action="new-arc"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showEntityModal(projectId, "Arc");
            });

            container.querySelector('[data-action="new-act"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showEntityModal(projectId, "Act");
            });

            container.querySelector('[data-action="new-beat"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showEntityModal(projectId, "Beat");
            });

            container.querySelector('[data-action="new-thread"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showEntityModal(projectId, "Thread");
            });

            container.querySelector('[data-action="new-scene"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showEntityModal(projectId, "Scene");
            });

            const searchInput = container.querySelector("#plot-search-input");

            if (searchInput) {
                searchInput.addEventListener("input", () => {
                    this.uiState.search = searchInput.value || "";
                    this.render(this.container);
                });
            }

            container.querySelector('[data-action="clear-plot-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.search = "";
                this.render(this.container);
            });

            [
                ["#plot-entity-filter", "entityType"],
                ["#plot-status-filter", "status"],
                ["#plot-arc-filter", "arcId"],
                ["#plot-act-filter", "actId"],
                ["#plot-thread-filter", "threadId"],
                ["#plot-character-filter", "characterId"],
                ["#plot-location-filter", "locationId"],
                ["#plot-sort-filter", "sort"]
            ].forEach(([selector, key]) => {

                const input = container.querySelector(selector);

                input?.addEventListener("change", () => {
                    this.uiState[key] = input.value || "All";
                    this.render(this.container);
                });

            });

            container.querySelectorAll('[data-action="clear-plot-filters"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.clearFilters();
                });
            });

            container.querySelectorAll('[data-action="open-plot-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openEntity(button.dataset.entityType, button.dataset.entityId);
                });
            });

            container.querySelectorAll('[data-action="edit-plot-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const entityType = button.dataset.entityType;
                    const entityId = button.dataset.entityId;

                    if (entityType === "Overview") {
                        this.showOverviewModal(projectId);
                        return;
                    }

                    this.showEntityModal(projectId, entityType, entityId);
                });
            });

            container.querySelectorAll('[data-action="duplicate-plot-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.duplicateEntity(projectId, button.dataset.entityType, button.dataset.entityId);
                });
            });

            container.querySelectorAll('[data-action="archive-plot-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.archiveEntity(projectId, button.dataset.entityType, button.dataset.entityId);
                });
            });

            container.querySelectorAll('[data-action="restore-plot-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.restoreEntity(projectId, button.dataset.entityType, button.dataset.entityId);
                });
            });

            container.querySelectorAll('[data-action="delete-plot-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.confirmDeleteEntity(projectId, button.dataset.entityType, button.dataset.entityId);
                });
            });

            container.querySelectorAll('[data-action="move-plot-entity-up"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.moveEntity(projectId, button.dataset.entityType, button.dataset.entityId, -1);
                });
            });

            container.querySelectorAll('[data-action="move-plot-entity-down"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.moveEntity(projectId, button.dataset.entityType, button.dataset.entityId, 1);
                });
            });

            container.querySelectorAll('[data-action="add-thread-reference"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showThreadReferenceModal(projectId, button.dataset.threadId);
                });
            });

            container.querySelectorAll('[data-action="edit-thread-reference"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const index = Number(button.dataset.referenceIndex);

                    this.showThreadReferenceModal(
                        projectId,
                        button.dataset.threadId,
                        Number.isFinite(index) ? index : -1
                    );
                });
            });

            container.querySelectorAll('[data-action="remove-thread-reference"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const index = Number(button.dataset.referenceIndex);

                    this.removeThreadReference(
                        projectId,
                        button.dataset.threadId,
                        Number.isFinite(index) ? index : -1
                    );
                });
            });

            container.querySelectorAll('[data-action="open-scene-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openSceneChapter(projectId, button.dataset.chapterId);
                });
            });

            container.querySelectorAll('[data-action="open-scene-character"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("characters");
                });
            });

            container.querySelectorAll('[data-action="open-scene-world"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("world");
                });
            });

        },


        openEntity(entityType, entityId) {

            this.selectedEntity = {
                type: entityType,
                id: entityId
            };

            this.render(this.container);

        },


        showOverviewModal(projectId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const plot = this.getPlot(project);
            const overview = plot.overview;

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="plot-overview-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">PLOT STUDIO</p>
                                <h2 id="plot-overview-modal-title">Story Overview</h2>
                                <p>Capture the core direction of your story.</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-plot-modal" aria-label="Close plot overview form">×</button>
                        </header>

                        <form id="plot-overview-form" class="project-form" novalidate>
                            <div class="project-form-grid">

                                <label class="form-field form-field-wide" for="plot-overview-title-input">
                                    <span>Overview Title</span>
                                    <input id="plot-overview-title-input" name="title" type="text" autocomplete="off" value="${this.escapeHTML(overview.title || this.getProjectTitle(project))}" />
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-premise-input">
                                    <span>Premise</span>
                                    <textarea id="plot-overview-premise-input" name="premise" rows="3">${this.escapeHTML(overview.premise || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-conflict-input">
                                    <span>Central Conflict</span>
                                    <textarea id="plot-overview-conflict-input" name="centralConflict" rows="3">${this.escapeHTML(overview.centralConflict || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-stakes-input">
                                    <span>Stakes</span>
                                    <textarea id="plot-overview-stakes-input" name="stakes" rows="3">${this.escapeHTML(overview.stakes || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-theme-input">
                                    <span>Theme</span>
                                    <textarea id="plot-overview-theme-input" name="theme" rows="3">${this.escapeHTML(overview.theme || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-synopsis-input">
                                    <span>Synopsis</span>
                                    <textarea id="plot-overview-synopsis-input" name="synopsis" rows="4">${this.escapeHTML(overview.synopsis || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-ending-input">
                                    <span>Ending</span>
                                    <textarea id="plot-overview-ending-input" name="ending" rows="3">${this.escapeHTML(overview.ending || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="plot-overview-notes-input">
                                    <span>Notes</span>
                                    <textarea id="plot-overview-notes-input" name="notes" rows="4">${this.escapeHTML(overview.notes || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-plot-modal">Cancel</button>
                                <button type="submit" class="button button-primary">Save Overview</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-plot-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#plot-overview-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleOverviewSubmit(projectId, event.currentTarget);
            });

            this.modalContainer.querySelector("#plot-overview-title-input")?.focus();

        },


        handleOverviewSubmit(projectId, form) {

            const formData = new FormData(form);
            const now = new Date().toISOString();

            const saved = this.updateProjectPlot(
                projectId,
                plot => {

                    const nextOverview = this.normalizeOverview(
                        {
                            ...plot.overview,
                            title: String(formData.get("title") || "").trim() || plot.overview.title,
                            premise: String(formData.get("premise") || ""),
                            centralConflict: String(formData.get("centralConflict") || ""),
                            stakes: String(formData.get("stakes") || ""),
                            theme: String(formData.get("theme") || ""),
                            synopsis: String(formData.get("synopsis") || ""),
                            ending: String(formData.get("ending") || ""),
                            notes: String(formData.get("notes") || ""),
                            updatedAt: now
                        },
                        projectId,
                        plot.overview.title
                    );

                    if (!nextOverview) {
                        return null;
                    }

                    return {
                        ...plot,
                        overview: nextOverview
                    };

                },
                "plot-overview-update"
            );

            if (!saved) {
                this.core.notify("Failed to save plot overview.", "error");
                return;
            }

            this.selectedEntity = {
                type: "Overview",
                id: this.selectedEntity.id || "overview"
            };

            this.closeModal();
            this.core.notify("Plot overview updated.", "success");
            this.render(this.container);

        },


        showEntityModal(projectId, entityType, entityId = null) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const plot = this.getPlot(project);
            const isEditing = Boolean(entityId);

            const existing = entityId
                ? this.getEntityByType(plot, entityType, entityId)
                : null;

            if (entityId && !existing) {
                this.core.notify("Plot entity could not be found.", "error");
                return;
            }

            const title = isEditing
                ? `Edit ${entityType}`
                : `New ${entityType}`;

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="plot-entity-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">PLOT STUDIO</p>
                                <h2 id="plot-entity-modal-title">${this.escapeHTML(title)}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-plot-modal" aria-label="Close plot form">×</button>
                        </header>

                        <form id="plot-entity-form" class="project-form" novalidate>
                            <input type="hidden" name="entityType" value="${this.escapeHTML(entityType)}" />
                            <div class="project-form-grid">
                                ${this.renderEntityFormFields(project, plot, entityType, existing)}
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-plot-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${isEditing ? "Save Changes" : `Save ${this.escapeHTML(entityType)}`}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-plot-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#plot-entity-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleEntitySubmit(projectId, entityType, entityId, event.currentTarget);
            });

            this.modalContainer.querySelector('[name="title"]')?.focus();

        },


        renderEntityFormFields(project, plot, entityType, existing) {

            const arcs = plot.arcs;
            const acts = plot.acts;
            const threads = plot.threads;
            const chapters = this.getProjectChapters(project);
            const characters = this.getProjectCharacters(project);
            const locations = this.getProjectLocations(project);

            const sharedTitle = `
                <label class="form-field form-field-wide" for="plot-entity-title-input">
                    <span>Title *</span>
                    <input id="plot-entity-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(existing?.title || "")}" />
                </label>
            `;

            if (entityType === "Arc") {
                return `
                    ${sharedTitle}
                    <label class="form-field" for="plot-arc-status-input">
                        <span>Status</span>
                        <select id="plot-arc-status-input" name="status">
                            ${this.plotStatuses.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.status || "Draft") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field form-field-wide" for="plot-arc-summary-input">
                        <span>Summary</span>
                        <textarea id="plot-arc-summary-input" name="summary" rows="3">${this.escapeHTML(existing?.summary || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-arc-purpose-input">
                        <span>Purpose</span>
                        <textarea id="plot-arc-purpose-input" name="purpose" rows="3">${this.escapeHTML(existing?.purpose || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-arc-beginning-input">
                        <span>Beginning</span>
                        <textarea id="plot-arc-beginning-input" name="beginning" rows="2">${this.escapeHTML(existing?.beginning || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-arc-midpoint-input">
                        <span>Midpoint</span>
                        <textarea id="plot-arc-midpoint-input" name="midpoint" rows="2">${this.escapeHTML(existing?.midpoint || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-arc-ending-input">
                        <span>Ending</span>
                        <textarea id="plot-arc-ending-input" name="ending" rows="2">${this.escapeHTML(existing?.ending || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-arc-notes-input">
                        <span>Notes</span>
                        <textarea id="plot-arc-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                    </label>
                `;
            }

            if (entityType === "Act") {
                return `
                    ${sharedTitle}
                    <label class="form-field form-field-wide" for="plot-act-summary-input">
                        <span>Summary</span>
                        <textarea id="plot-act-summary-input" name="summary" rows="3">${this.escapeHTML(existing?.summary || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-act-notes-input">
                        <span>Notes</span>
                        <textarea id="plot-act-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                    </label>
                `;
            }

            if (entityType === "Beat") {
                return `
                    ${sharedTitle}
                    <label class="form-field" for="plot-beat-type-input">
                        <span>Beat Type</span>
                        <input id="plot-beat-type-input" name="type" type="text" list="plot-beat-type-list" value="${this.escapeHTML(existing?.type || "Custom")}" />
                        <datalist id="plot-beat-type-list">
                            ${this.beatTypes.map(type => `<option value="${this.escapeHTML(type)}"></option>`).join("")}
                        </datalist>
                    </label>
                    <label class="form-field" for="plot-beat-status-input">
                        <span>Status</span>
                        <select id="plot-beat-status-input" name="status">
                            ${this.plotStatuses.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.status || "Draft") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-beat-arc-input">
                        <span>Arc</span>
                        <select id="plot-beat-arc-input" name="arcId">
                            <option value="">Unlinked</option>
                            ${arcs.map(arc => `<option value="${this.escapeHTML(arc.id)}" ${existing?.arcId === arc.id ? "selected" : ""}>${this.escapeHTML(arc.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-beat-act-input">
                        <span>Act</span>
                        <select id="plot-beat-act-input" name="actId">
                            <option value="">Unlinked</option>
                            ${acts.map(act => `<option value="${this.escapeHTML(act.id)}" ${existing?.actId === act.id ? "selected" : ""}>${this.escapeHTML(act.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field form-field-wide" for="plot-beat-threads-input">
                        <span>Threads</span>
                        <select id="plot-beat-threads-input" name="threadIds" multiple size="4">
                            ${threads.map(thread => `<option value="${this.escapeHTML(thread.id)}" ${Array.isArray(existing?.threadIds) && existing.threadIds.includes(thread.id) ? "selected" : ""}>${this.escapeHTML(thread.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field form-field-wide" for="plot-beat-description-input">
                        <span>Description</span>
                        <textarea id="plot-beat-description-input" name="description" rows="3">${this.escapeHTML(existing?.description || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-beat-notes-input">
                        <span>Notes</span>
                        <textarea id="plot-beat-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                    </label>
                `;
            }

            if (entityType === "Thread") {
                return `
                    ${sharedTitle}
                    <label class="form-field" for="plot-thread-type-input">
                        <span>Thread Type</span>
                        <input id="plot-thread-type-input" name="type" type="text" list="plot-thread-type-list" value="${this.escapeHTML(existing?.type || "Subplot")}" />
                        <datalist id="plot-thread-type-list">
                            ${this.threadTypes.map(type => `<option value="${this.escapeHTML(type)}"></option>`).join("")}
                        </datalist>
                    </label>
                    <label class="form-field" for="plot-thread-status-input">
                        <span>Status</span>
                        <select id="plot-thread-status-input" name="status">
                            ${this.plotStatuses.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.status || "Draft") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field form-field-wide" for="plot-thread-summary-input">
                        <span>Summary</span>
                        <textarea id="plot-thread-summary-input" name="summary" rows="3">${this.escapeHTML(existing?.summary || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-thread-notes-input">
                        <span>Notes</span>
                        <textarea id="plot-thread-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                    </label>
                `;
            }

            if (entityType === "Scene") {
                return `
                    ${sharedTitle}
                    <label class="form-field" for="plot-scene-status-input">
                        <span>Status</span>
                        <select id="plot-scene-status-input" name="status">
                            ${this.sceneStatuses.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.status || "Planned") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-scene-arc-input">
                        <span>Arc</span>
                        <select id="plot-scene-arc-input" name="arcId">
                            <option value="">Unlinked</option>
                            ${arcs.map(arc => `<option value="${this.escapeHTML(arc.id)}" ${existing?.arcId === arc.id ? "selected" : ""}>${this.escapeHTML(arc.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-scene-act-input">
                        <span>Act</span>
                        <select id="plot-scene-act-input" name="actId">
                            <option value="">Unlinked</option>
                            ${acts.map(act => `<option value="${this.escapeHTML(act.id)}" ${existing?.actId === act.id ? "selected" : ""}>${this.escapeHTML(act.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-scene-chapter-input">
                        <span>Chapter Link</span>
                        <select id="plot-scene-chapter-input" name="chapterId">
                            <option value="">Unlinked</option>
                            ${chapters.map(chapter => `<option value="${this.escapeHTML(chapter.id)}" ${existing?.chapterId === chapter.id ? "selected" : ""}>${this.escapeHTML(chapter.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-scene-character-input">
                        <span>POV Character</span>
                        <select id="plot-scene-character-input" name="povCharacterId">
                            <option value="">Unassigned</option>
                            ${characters.map(character => `<option value="${this.escapeHTML(character.id)}" ${existing?.povCharacterId === character.id ? "selected" : ""}>${this.escapeHTML(this.getCharacterName(character))}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-scene-location-input">
                        <span>Location</span>
                        <select id="plot-scene-location-input" name="locationId">
                            <option value="">Unassigned</option>
                            ${locations.map(location => `<option value="${this.escapeHTML(location.id)}" ${existing?.locationId === location.id ? "selected" : ""}>${this.escapeHTML(location.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field" for="plot-scene-time-input">
                        <span>Time</span>
                        <input id="plot-scene-time-input" name="time" type="text" autocomplete="off" value="${this.escapeHTML(existing?.time || "")}" />
                    </label>
                    <label class="form-field form-field-wide" for="plot-scene-threads-input">
                        <span>Threads</span>
                        <select id="plot-scene-threads-input" name="threadIds" multiple size="4">
                            ${threads.map(thread => `<option value="${this.escapeHTML(thread.id)}" ${Array.isArray(existing?.threadIds) && existing.threadIds.includes(thread.id) ? "selected" : ""}>${this.escapeHTML(thread.title)}</option>`).join("")}
                        </select>
                    </label>
                    <label class="form-field form-field-wide" for="plot-scene-summary-input">
                        <span>Summary</span>
                        <textarea id="plot-scene-summary-input" name="summary" rows="3">${this.escapeHTML(existing?.summary || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-scene-goal-input">
                        <span>Goal</span>
                        <textarea id="plot-scene-goal-input" name="goal" rows="3">${this.escapeHTML(existing?.goal || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-scene-conflict-input">
                        <span>Conflict</span>
                        <textarea id="plot-scene-conflict-input" name="conflict" rows="3">${this.escapeHTML(existing?.conflict || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-scene-outcome-input">
                        <span>Outcome</span>
                        <textarea id="plot-scene-outcome-input" name="outcome" rows="3">${this.escapeHTML(existing?.outcome || "")}</textarea>
                    </label>
                    <label class="form-field form-field-wide" for="plot-scene-notes-input">
                        <span>Notes</span>
                        <textarea id="plot-scene-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                    </label>
                `;
            }

            return sharedTitle;

        },


        handleEntitySubmit(projectId, entityType, entityId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify(`${entityType} title is required.`, "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const now = new Date().toISOString();

            const shared = {
                title,
                updatedAt: now
            };

            const selectedMulti = name =>
                Array.from(form.querySelectorAll(`[name="${name}"] option:checked`))
                    .map(option => String(option.value || "").trim())
                    .filter(Boolean);

            let payload = null;

            if (entityType === "Arc") {
                payload = {
                    ...shared,
                    summary: String(formData.get("summary") || ""),
                    purpose: String(formData.get("purpose") || ""),
                    status: String(formData.get("status") || "Draft"),
                    beginning: String(formData.get("beginning") || ""),
                    midpoint: String(formData.get("midpoint") || ""),
                    ending: String(formData.get("ending") || ""),
                    notes: String(formData.get("notes") || "")
                };
            }

            if (entityType === "Act") {
                payload = {
                    ...shared,
                    summary: String(formData.get("summary") || ""),
                    notes: String(formData.get("notes") || "")
                };
            }

            if (entityType === "Beat") {
                payload = {
                    ...shared,
                    description: String(formData.get("description") || ""),
                    type: String(formData.get("type") || "Custom").trim() || "Custom",
                    arcId: String(formData.get("arcId") || "").trim(),
                    actId: String(formData.get("actId") || "").trim(),
                    threadIds: selectedMulti("threadIds"),
                    status: String(formData.get("status") || "Draft").trim() || "Draft",
                    notes: String(formData.get("notes") || "")
                };
            }

            if (entityType === "Thread") {
                payload = {
                    ...shared,
                    summary: String(formData.get("summary") || ""),
                    type: String(formData.get("type") || "Subplot").trim() || "Subplot",
                    status: String(formData.get("status") || "Draft").trim() || "Draft",
                    notes: String(formData.get("notes") || "")
                };
            }

            if (entityType === "Scene") {
                payload = {
                    ...shared,
                    summary: String(formData.get("summary") || ""),
                    goal: String(formData.get("goal") || ""),
                    conflict: String(formData.get("conflict") || ""),
                    outcome: String(formData.get("outcome") || ""),
                    povCharacterId: String(formData.get("povCharacterId") || "").trim(),
                    locationId: String(formData.get("locationId") || "").trim(),
                    chapterId: String(formData.get("chapterId") || "").trim(),
                    arcId: String(formData.get("arcId") || "").trim(),
                    actId: String(formData.get("actId") || "").trim(),
                    threadIds: selectedMulti("threadIds"),
                    time: String(formData.get("time") || ""),
                    status: String(formData.get("status") || "Planned").trim() || "Planned",
                    notes: String(formData.get("notes") || "")
                };
            }

            if (!payload) {
                this.core.notify("Unsupported plot entity type.", "error");
                return;
            }

            const saved = entityId
                ? this.updateEntity(projectId, entityType, entityId, payload)
                : this.createEntity(projectId, entityType, payload);

            if (!saved) {
                this.core.notify(`Failed to save ${entityType.toLowerCase()}.`, "error");
                return;
            }

            this.closeModal();
            this.core.notify(`${entityType} ${entityId ? "updated" : "created"}.`, "success");
            this.render(this.container);

        },


        getEntityCollectionKey(entityType) {

            const map = {
                Arc: "arcs",
                Act: "acts",
                Beat: "beats",
                Thread: "threads",
                Scene: "scenes"
            };

            return map[entityType] || null;

        },


        getEntityByType(plot, entityType, entityId) {

            const collectionKey = this.getEntityCollectionKey(entityType);

            if (!collectionKey) {
                return null;
            }

            return plot[collectionKey].find(item => item.id === entityId) || null;

        },


        createEntity(projectId, entityType, payload) {

            const collectionKey = this.getEntityCollectionKey(entityType);

            if (!collectionKey) {
                return false;
            }

            return this.updateProjectPlot(
                projectId,
                plot => {

                    const current = Array.isArray(plot[collectionKey])
                        ? [...plot[collectionKey]]
                        : [];

                    const now = new Date().toISOString();

                    const candidate = {
                        ...payload,
                        id: AuthorOSHelpers.generateId(entityType.toLowerCase()),
                        projectId,
                        order: current.length + 1,
                        createdAt: now,
                        updatedAt: now
                    };

                    if (entityType === "Arc") {
                        candidate.archivedAt = null;
                    }

                    if (entityType === "Beat") {
                        candidate.archivedAt = null;
                    }

                    if (entityType === "Thread") {
                        candidate.references = [];
                        candidate.archivedAt = null;
                    }

                    if (entityType === "Scene") {
                        candidate.archivedAt = null;
                    }

                    const normalizer = this.getEntityNormalizer(entityType);
                    const normalized = normalizer(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    const next = {
                        ...plot,
                        [collectionKey]: [...current, normalized]
                    };

                    return this.normalizePlot(next, projectId);

                },
                `plot-${collectionKey}-create`,
                nextPlot => {

                    const latest = nextPlot[collectionKey][nextPlot[collectionKey].length - 1];

                    if (latest) {
                        this.selectedEntity = {
                            type: entityType,
                            id: latest.id
                        };
                    }

                }
            );

        },


        updateEntity(projectId, entityType, entityId, updates) {

            const collectionKey = this.getEntityCollectionKey(entityType);

            if (!collectionKey) {
                return false;
            }

            return this.updateProjectPlot(
                projectId,
                plot => {

                    const collection = Array.isArray(plot[collectionKey])
                        ? [...plot[collectionKey]]
                        : [];

                    const index = collection.findIndex(item => item.id === entityId);

                    if (index === -1) {
                        return null;
                    }

                    const existing = collection[index];
                    const normalizer = this.getEntityNormalizer(entityType);

                    const candidate = {
                        ...existing,
                        ...updates,
                        id: existing.id,
                        projectId: existing.projectId,
                        createdAt: existing.createdAt,
                        order: existing.order,
                        references: entityType === "Thread"
                            ? Array.isArray(existing.references) ? existing.references : []
                            : existing.references,
                        threadIds: ["Beat", "Scene"].includes(entityType)
                            ? Array.isArray(updates.threadIds) ? updates.threadIds : Array.isArray(existing.threadIds) ? existing.threadIds : []
                            : existing.threadIds
                    };

                    const normalized = normalizer(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    collection[index] = normalized;

                    return this.normalizePlot(
                        {
                            ...plot,
                            [collectionKey]: collection
                        },
                        projectId
                    );

                },
                `plot-${collectionKey}-update`,
                () => {
                    this.selectedEntity = {
                        type: entityType,
                        id: entityId
                    };
                }
            );

        },


        duplicateEntity(projectId, entityType, entityId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                return;
            }

            const plot = this.getPlot(project);
            const source = this.getEntityByType(plot, entityType, entityId);

            if (!source) {
                this.core.notify("Plot entity could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();

            const duplicate = {
                ...source,
                id: AuthorOSHelpers.generateId(entityType.toLowerCase()),
                title: `${source.title} - Copy`,
                createdAt: now,
                updatedAt: now,
                order: (Array.isArray(plot[this.getEntityCollectionKey(entityType)])
                    ? plot[this.getEntityCollectionKey(entityType)].length
                    : 0) + 1
            };

            if (["Arc", "Beat", "Thread", "Scene"].includes(entityType)) {
                duplicate.status = source.status === "Archived"
                    ? (entityType === "Scene" ? "Planned" : "Draft")
                    : source.status;
                duplicate.archivedAt = null;
            }

            if (entityType === "Thread") {
                duplicate.references = Array.isArray(source.references)
                    ? source.references
                        .map(reference => this.normalizeReference(
                            {
                                ...reference,
                                sourceId: ""
                            },
                            projectId,
                            ""
                        ))
                        .filter(Boolean)
                    : [];
            }

            const saved = this.createEntity(projectId, entityType, duplicate);

            if (!saved) {
                this.core.notify("Failed to duplicate plot entity.", "error");
                return;
            }

            this.core.notify(`${entityType} duplicated.`, "success");
            this.render(this.container);

        },


        moveEntity(projectId, entityType, entityId, direction) {

            const collectionKey = this.getEntityCollectionKey(entityType);

            if (!collectionKey) {
                return;
            }

            const saved = this.updateProjectPlot(
                projectId,
                plot => {

                    const collection = Array.isArray(plot[collectionKey])
                        ? [...plot[collectionKey]]
                        : [];

                    const index = collection.findIndex(item => item.id === entityId);

                    if (index === -1) {
                        return null;
                    }

                    const target = index + direction;

                    if (target < 0 || target >= collection.length) {
                        return null;
                    }

                    const temp = collection[index];
                    collection[index] = collection[target];
                    collection[target] = temp;

                    const now = new Date().toISOString();

                    const reordered = collection.map((item, itemIndex) => ({
                        ...item,
                        order: itemIndex + 1,
                        updatedAt: now
                    }));

                    return this.normalizePlot(
                        {
                            ...plot,
                            [collectionKey]: reordered
                        },
                        projectId
                    );

                },
                `plot-${collectionKey}-reorder`,
                () => {
                    this.selectedEntity = {
                        type: entityType,
                        id: entityId
                    };
                }
            );

            if (!saved) {
                return;
            }

            this.core.notify(`${entityType} reordered.`, "success");
            this.render(this.container);

        },


        archiveEntity(projectId, entityType, entityId) {

            const statusValue = entityType === "Scene"
                ? "Archived"
                : "Archived";

            const now = new Date().toISOString();

            const saved = this.updateEntity(
                projectId,
                entityType,
                entityId,
                {
                    status: statusValue,
                    archivedAt: now,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify(`Failed to archive ${entityType.toLowerCase()}.`, "error");
                return;
            }

            this.core.notify(`${entityType} archived.`, "success");
            this.render(this.container);

        },


        restoreEntity(projectId, entityType, entityId) {

            const fallback = entityType === "Scene"
                ? "Planned"
                : "Draft";

            const now = new Date().toISOString();

            const saved = this.updateEntity(
                projectId,
                entityType,
                entityId,
                {
                    status: fallback,
                    archivedAt: null,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify(`Failed to restore ${entityType.toLowerCase()}.`, "error");
                return;
            }

            this.core.notify(`${entityType} restored.`, "success");
            this.render(this.container);

        },


        confirmDeleteEntity(projectId, entityType, entityId) {

            const project = this.getProjectById(projectId);
            const plot = this.getPlot(project);
            const entity = this.getEntityByType(plot, entityType, entityId);

            if (!entity) {
                this.core.notify("Plot entity could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: `Delete ${entityType}`,
                content: `
                    <p>Delete \"${this.escapeHTML(entity.title)}\"?</p>
                    <p>This action removes the stored plot item but does not change manuscript text.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {

                    if (!this.deleteEntity(projectId, entityType, entityId)) {
                        this.core.notify(`Failed to delete ${entityType.toLowerCase()}.`, "error");
                        return;
                    }

                    this.core.notify(`${entityType} deleted.`, "success");
                    this.render(this.container);

                }
            });

        },


        deleteEntity(projectId, entityType, entityId) {

            const collectionKey = this.getEntityCollectionKey(entityType);

            if (!collectionKey) {
                return false;
            }

            return this.updateProjectPlot(
                projectId,
                plot => {

                    const collection = Array.isArray(plot[collectionKey])
                        ? [...plot[collectionKey]]
                        : [];

                    const exists = collection.some(item => item.id === entityId);

                    if (!exists) {
                        return null;
                    }

                    const filtered = collection
                        .filter(item => item.id !== entityId)
                        .map((item, index) => ({
                            ...item,
                            order: index + 1
                        }));

                    const next = {
                        ...plot,
                        [collectionKey]: filtered
                    };

                    if (entityType === "Arc") {

                        next.beats = next.beats.map(beat => ({
                            ...beat,
                            arcId: beat.arcId === entityId ? "" : beat.arcId
                        }));

                        next.scenes = next.scenes.map(scene => ({
                            ...scene,
                            arcId: scene.arcId === entityId ? "" : scene.arcId
                        }));

                    }

                    if (entityType === "Act") {

                        next.beats = next.beats.map(beat => ({
                            ...beat,
                            actId: beat.actId === entityId ? "" : beat.actId
                        }));

                        next.scenes = next.scenes.map(scene => ({
                            ...scene,
                            actId: scene.actId === entityId ? "" : scene.actId
                        }));

                    }

                    if (entityType === "Thread") {

                        next.beats = next.beats.map(beat => ({
                            ...beat,
                            threadIds: Array.isArray(beat.threadIds)
                                ? beat.threadIds.filter(id => id !== entityId)
                                : []
                        }));

                        next.scenes = next.scenes.map(scene => ({
                            ...scene,
                            threadIds: Array.isArray(scene.threadIds)
                                ? scene.threadIds.filter(id => id !== entityId)
                                : []
                        }));

                    }

                    if (["Arc", "Act", "Beat", "Scene", "Thread"].includes(entityType)) {

                        next.threads = next.threads.map(thread => ({
                            ...thread,
                            references: Array.isArray(thread.references)
                                ? thread.references.filter(reference => !(
                                    reference.targetKind === entityType.toLowerCase() &&
                                    reference.targetId === entityId
                                ))
                                : []
                        }));

                    }

                    return this.normalizePlot(next, projectId);

                },
                `plot-${collectionKey}-delete`,
                () => {

                    if (
                        this.selectedEntity.type === entityType &&
                        this.selectedEntity.id === entityId
                    ) {
                        this.selectedEntity = {
                            type: "Overview",
                            id: "overview"
                        };
                    }

                }
            );

        },


        showThreadReferenceModal(projectId, threadId, referenceIndex = -1) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const plot = this.getPlot(project);
            const thread = this.getEntityByType(plot, "Thread", threadId);

            if (!thread) {
                this.core.notify("Thread could not be found.", "error");
                return;
            }

            const references = Array.isArray(thread.references)
                ? thread.references
                : [];

            const editingReference = referenceIndex >= 0
                ? references[referenceIndex] || null
                : null;

            const targetKind = String(editingReference?.targetKind || "scene");
            const targetId = String(editingReference?.targetId || "");

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="plot-thread-reference-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">PLOT THREAD REFERENCE</p>
                                <h2 id="plot-thread-reference-modal-title">${editingReference ? "Edit Reference" : "Add Reference"}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-thread-reference-modal" aria-label="Close reference form">×</button>
                        </header>

                        <form id="plot-thread-reference-form" class="project-form" novalidate>
                            <div class="project-form-grid">

                                <label class="form-field" for="plot-thread-reference-target-kind-input">
                                    <span>Target Type</span>
                                    <select id="plot-thread-reference-target-kind-input" name="targetKind">
                                        ${["arc", "act", "beat", "scene", "thread", "character", "world", "chapter"]
                                            .map(kind => `<option value="${kind}" ${targetKind === kind ? "selected" : ""}>${kind}</option>`)
                                            .join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="plot-thread-reference-target-id-input">
                                    <span>Target</span>
                                    <select id="plot-thread-reference-target-id-input" name="targetId"></select>
                                </label>

                                <label class="form-field" for="plot-thread-reference-type-input">
                                    <span>Relationship Type</span>
                                    <input id="plot-thread-reference-type-input" name="relationshipType" type="text" autocomplete="off" value="${this.escapeHTML(editingReference?.relationshipType || "Related")}" />
                                </label>

                                <label class="form-field form-field-wide" for="plot-thread-reference-description-input">
                                    <span>Description</span>
                                    <textarea id="plot-thread-reference-description-input" name="description" rows="3">${this.escapeHTML(editingReference?.description || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-thread-reference-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${editingReference ? "Save Reference" : "Add Reference"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-thread-reference-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            const targetKindInput = this.modalContainer.querySelector("#plot-thread-reference-target-kind-input");
            const targetIdInput = this.modalContainer.querySelector("#plot-thread-reference-target-id-input");

            const renderOptions = () => {

                const kind = String(targetKindInput?.value || "scene");
                const options = this.getReferenceTargetsByKind(project, plot, kind, thread.id);

                targetIdInput.innerHTML = `
                    <option value="">Select target</option>
                    ${options.map(option => `
                        <option value="${this.escapeHTML(option.id)}" ${targetId === option.id ? "selected" : ""}>${this.escapeHTML(option.label)}</option>
                    `).join("")}
                `;

            };

            renderOptions();

            targetKindInput?.addEventListener("change", () => {
                renderOptions();
            });

            this.modalContainer.querySelector("#plot-thread-reference-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleThreadReferenceSubmit(projectId, thread.id, referenceIndex, event.currentTarget);
            });

        },


        handleThreadReferenceSubmit(projectId, threadId, referenceIndex, form) {

            const formData = new FormData(form);

            const targetKind = String(formData.get("targetKind") || "").trim().toLowerCase();
            const targetId = String(formData.get("targetId") || "").trim();
            const relationshipType = String(formData.get("relationshipType") || "Related").trim() || "Related";
            const description = String(formData.get("description") || "");

            if (!targetId) {
                this.core.notify("Select a reference target.", "error");
                form.querySelector('[name="targetId"]')?.focus();
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const plot = this.getPlot(project);

            const validTarget = this.validateReferenceTarget(project, plot, targetKind, targetId, threadId);

            if (!validTarget) {
                this.core.notify("Invalid or cross-project reference target.", "error");
                return;
            }

            const saved = this.updateProjectPlot(
                projectId,
                currentPlot => {

                    const threads = Array.isArray(currentPlot.threads)
                        ? [...currentPlot.threads]
                        : [];

                    const threadIndex = threads.findIndex(thread => thread.id === threadId);

                    if (threadIndex === -1) {
                        return null;
                    }

                    const sourceThread = threads[threadIndex];
                    const refs = Array.isArray(sourceThread.references)
                        ? [...sourceThread.references]
                        : [];

                    const nextReference = this.normalizeReference(
                        {
                            sourceId: sourceThread.id,
                            targetKind,
                            targetId,
                            relationshipType,
                            description,
                            projectId
                        },
                        projectId,
                        sourceThread.id
                    );

                    if (!nextReference) {
                        return null;
                    }

                    if (referenceIndex >= 0 && referenceIndex < refs.length) {
                        refs[referenceIndex] = nextReference;
                    } else {
                        refs.push(nextReference);
                    }

                    const now = new Date().toISOString();

                    const updatedThread = this.normalizeThread(
                        {
                            ...sourceThread,
                            references: refs,
                            updatedAt: now
                        },
                        projectId
                    );

                    if (!updatedThread) {
                        return null;
                    }

                    threads[threadIndex] = updatedThread;

                    return this.normalizePlot(
                        {
                            ...currentPlot,
                            threads
                        },
                        projectId
                    );

                },
                "plot-thread-reference-save",
                () => {
                    this.selectedEntity = {
                        type: "Thread",
                        id: threadId
                    };
                }
            );

            if (!saved) {
                this.core.notify("Failed to save thread reference.", "error");
                return;
            }

            this.closeModal();
            this.core.notify(referenceIndex >= 0 ? "Reference updated." : "Reference added.", "success");
            this.render(this.container);

        },


        removeThreadReference(projectId, threadId, referenceIndex) {

            const saved = this.updateProjectPlot(
                projectId,
                plot => {

                    const threads = Array.isArray(plot.threads)
                        ? [...plot.threads]
                        : [];

                    const threadIndex = threads.findIndex(thread => thread.id === threadId);

                    if (threadIndex === -1) {
                        return null;
                    }

                    const sourceThread = threads[threadIndex];
                    const refs = Array.isArray(sourceThread.references)
                        ? [...sourceThread.references]
                        : [];

                    if (referenceIndex < 0 || referenceIndex >= refs.length) {
                        return null;
                    }

                    refs.splice(referenceIndex, 1);

                    const updatedThread = this.normalizeThread(
                        {
                            ...sourceThread,
                            references: refs,
                            updatedAt: new Date().toISOString()
                        },
                        projectId
                    );

                    if (!updatedThread) {
                        return null;
                    }

                    threads[threadIndex] = updatedThread;

                    return this.normalizePlot(
                        {
                            ...plot,
                            threads
                        },
                        projectId
                    );

                },
                "plot-thread-reference-remove",
                () => {
                    this.selectedEntity = {
                        type: "Thread",
                        id: threadId
                    };
                }
            );

            if (!saved) {
                this.core.notify("Failed to remove reference.", "error");
                return;
            }

            this.core.notify("Reference removed.", "success");
            this.render(this.container);

        },


        openSceneChapter(projectId, chapterId) {

            if (!projectId || !chapterId) {
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                return;
            }

            const nextProject = this.cloneData(project);

            if (!nextProject) {
                this.core.navigation.navigate("manuscript");
                return;
            }

            if (!nextProject.manuscript || typeof nextProject.manuscript !== "object") {
                nextProject.manuscript = {};
            }

            nextProject.manuscript.lastOpenedChapterId = chapterId;
            nextProject.updatedAt = new Date().toISOString();
            nextProject.lastModified = nextProject.updatedAt;

            this.persistProject(nextProject, "plot-open-chapter");
            this.core.navigation.navigate("manuscript");

        },


        getEntityNormalizer(entityType) {

            const map = {
                Arc: this.normalizeArc.bind(this),
                Act: this.normalizeAct.bind(this),
                Beat: this.normalizeBeat.bind(this),
                Thread: this.normalizeThread.bind(this),
                Scene: this.normalizeScene.bind(this)
            };

            return map[entityType];

        },


        normalizePlot(plot, projectId) {

            const next = this.cloneData(plot);

            if (!next || typeof next !== "object") {
                return null;
            }

            if (!next.overview || typeof next.overview !== "object") {
                return null;
            }

            const normalizedOverview = this.normalizeOverview(next.overview, projectId, next.overview.title || "Story Overview");

            if (!normalizedOverview) {
                return null;
            }

            next.overview = normalizedOverview;

            const normalizers = {
                arcs: this.normalizeArc.bind(this),
                acts: this.normalizeAct.bind(this),
                beats: this.normalizeBeat.bind(this),
                threads: this.normalizeThread.bind(this),
                scenes: this.normalizeScene.bind(this)
            };

            Object.keys(normalizers).forEach(key => {

                const normalizer = normalizers[key];
                const list = Array.isArray(next[key]) ? next[key] : [];

                next[key] = list
                    .map(item => normalizer(item, projectId))
                    .filter(Boolean)
                    .sort((left, right) => Number(left.order || 0) - Number(right.order || 0))
                    .map((item, index) => ({
                        ...item,
                        order: index + 1
                    }));

            });

            return next;

        },


        updateProjectPlot(projectId, updater, source, onSuccess) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return false;
            }

            const hydrated = this.ensureProjectPlotShape(project);
            const nextProject = this.cloneData(hydrated.project);

            if (!nextProject) {
                return false;
            }

            const plot = this.getPlot(nextProject);
            const nextPlot = updater(plot);

            if (!nextPlot || typeof nextPlot !== "object") {
                return false;
            }

            const now = new Date().toISOString();

            nextProject.story.plot = nextPlot;
            nextProject.statistics = {
                ...(nextProject.statistics || {}),
                plot: Array.isArray(nextPlot.scenes)
                    ? nextPlot.scenes.filter(scene => String(scene.status || "") !== "Archived").length
                    : 0,
                plotScenes: Array.isArray(nextPlot.scenes)
                    ? nextPlot.scenes.length
                    : 0
            };
            nextProject.updatedAt = now;
            nextProject.lastModified = now;

            if (!this.persistProject(nextProject, source || "plot-update")) {
                return false;
            }

            if (typeof onSuccess === "function") {
                onSuccess(nextPlot);
            }

            return true;

        },


        persistProject(project, source) {

            const projects = this.core.state.get("projects");

            if (!Array.isArray(projects)) {
                return false;
            }

            const index = projects.findIndex(item => item.id === project.id);

            if (index === -1) {
                return false;
            }

            const next = [...projects];
            next[index] = project;

            const projectsModule = this.core.registry.get("projects");

            if (projectsModule && typeof projectsModule.saveProjects === "function") {

                const saved = projectsModule.saveProjects(next, { source: source || "plot" });

                if (!saved) {
                    return false;
                }

                const syncedProject = this.getProjectById(project.id) || project;
                this.core.state.set("currentProject", syncedProject);
                this.core.storage.saveActiveProjectId(project.id);
                return true;

            }

            const saved = this.core.storage.saveProjects(next);

            if (!saved) {
                return false;
            }

            this.core.state.set("projects", next);
            this.core.state.set("currentProject", project);
            this.core.storage.saveActiveProjectId(project.id);
            this.core.events.emit("storage:changed");

            return true;

        },


        resolveReferences(project, plot, references) {

            return references.map(reference => {

                const target = this.resolveReferenceTarget(project, plot, reference.targetKind, reference.targetId);

                return {
                    ...reference,
                    targetLabel: target
                        ? target.label
                        : `Missing ${reference.targetKind} reference`
                };

            });

        },


        resolveReferenceTarget(project, plot, targetKind, targetId) {

            const kind = String(targetKind || "").toLowerCase();

            if (kind === "arc") {
                const target = plot.arcs.find(item => item.id === targetId);
                return target ? { id: target.id, label: `Arc: ${target.title}` } : null;
            }

            if (kind === "act") {
                const target = plot.acts.find(item => item.id === targetId);
                return target ? { id: target.id, label: `Act: ${target.title}` } : null;
            }

            if (kind === "beat") {
                const target = plot.beats.find(item => item.id === targetId);
                return target ? { id: target.id, label: `Beat: ${target.title}` } : null;
            }

            if (kind === "scene") {
                const target = plot.scenes.find(item => item.id === targetId);
                return target ? { id: target.id, label: `Scene: ${target.title}` } : null;
            }

            if (kind === "thread") {
                const target = plot.threads.find(item => item.id === targetId);
                return target ? { id: target.id, label: `Thread: ${target.title}` } : null;
            }

            if (kind === "character") {
                const target = this.getCharacterById(project, targetId);
                return target ? { id: target.id, label: `Character: ${this.getCharacterName(target)}` } : null;
            }

            if (kind === "world") {
                const target = this.getWorldEntryById(project, targetId);
                return target ? { id: target.id, label: `World: ${target.title}` } : null;
            }

            if (kind === "chapter") {
                const target = this.getChapterById(project, targetId);
                return target ? { id: target.id, label: `Chapter: ${target.title}` } : null;
            }

            return null;

        },


        getReferenceTargetsByKind(project, plot, targetKind, sourceThreadId) {

            const kind = String(targetKind || "").toLowerCase();

            if (kind === "arc") {
                return plot.arcs.map(arc => ({ id: arc.id, label: arc.title }));
            }

            if (kind === "act") {
                return plot.acts.map(act => ({ id: act.id, label: act.title }));
            }

            if (kind === "beat") {
                return plot.beats.map(beat => ({ id: beat.id, label: beat.title }));
            }

            if (kind === "scene") {
                return plot.scenes.map(scene => ({ id: scene.id, label: scene.title }));
            }

            if (kind === "thread") {
                return plot.threads
                    .filter(thread => thread.id !== sourceThreadId)
                    .map(thread => ({ id: thread.id, label: thread.title }));
            }

            if (kind === "character") {
                return this.getProjectCharacters(project)
                    .map(character => ({ id: character.id, label: this.getCharacterName(character) }));
            }

            if (kind === "world") {
                return this.getProjectLocations(project)
                    .map(location => ({ id: location.id, label: location.title }));
            }

            if (kind === "chapter") {
                return this.getProjectChapters(project)
                    .map(chapter => ({ id: chapter.id, label: chapter.title }));
            }

            return [];

        },


        validateReferenceTarget(project, plot, targetKind, targetId, sourceThreadId) {

            const kind = String(targetKind || "").toLowerCase();

            if (kind === "thread" && targetId === sourceThreadId) {
                return false;
            }

            return Boolean(this.resolveReferenceTarget(project, plot, kind, targetId));

        },


        resolveThreadLabels(plot, threadIds) {

            if (!Array.isArray(threadIds)) {
                return [];
            }

            const lookup = new Map(plot.threads.map(thread => [thread.id, thread]));

            return threadIds.map(threadId => {

                const target = lookup.get(threadId);

                return target
                    ? target.title
                    : "Missing thread reference";

            });

        },


        getProjectCharacters(project) {

            return Array.isArray(project?.story?.characters)
                ? project.story.characters.filter(character => character && character.id)
                : [];

        },


        getCharacterById(project, characterId) {

            if (!characterId) {
                return null;
            }

            return this.getProjectCharacters(project).find(character => String(character.id) === String(characterId)) || null;

        },


        getCharacterName(character) {

            return String(character?.displayName || character?.name || "Unnamed Character").trim() || "Unnamed Character";

        },


        getProjectWorldEntries(project) {

            return Array.isArray(project?.story?.worldEntries)
                ? project.story.worldEntries.filter(entry => entry && entry.id)
                : [];

        },


        getProjectLocations(project) {

            return this.getProjectWorldEntries(project)
                .filter(entry => String(entry.type || "").trim() === "Location");

        },


        getWorldEntryById(project, worldId) {

            if (!worldId) {
                return null;
            }

            return this.getProjectWorldEntries(project).find(entry => String(entry.id) === String(worldId)) || null;

        },


        getProjectChapters(project) {

            return Array.isArray(project?.manuscript?.chapters)
                ? project.manuscript.chapters.filter(chapter => chapter && chapter.id)
                : [];

        },


        getChapterById(project, chapterId) {

            if (!chapterId) {
                return null;
            }

            return this.getProjectChapters(project).find(chapter => String(chapter.id) === String(chapterId)) || null;

        },


        getEntityTitle(entity) {
            return String(entity?.title || "Untitled").trim() || "Untitled";
        },


        isAllowedPlotStatus(status) {
            return this.plotStatuses.includes(String(status || "").trim());
        },


        isAllowedSceneStatus(status) {
            return this.sceneStatuses.includes(String(status || "").trim()) || String(status || "").trim() === "Archived";
        },


        getPlotSummaryCounts(projectId = null) {

            const targetProject = projectId
                ? this.getProjectById(projectId)
                : this.getActiveProject();

            if (!targetProject) {
                return {
                    arcs: 0,
                    acts: 0,
                    beats: 0,
                    threads: 0,
                    scenes: 0,
                    plannedScenes: 0,
                    completeScenes: 0
                };
            }

            const plot = this.getPlot(targetProject);

            return {
                arcs: plot.arcs.length,
                acts: plot.acts.length,
                beats: plot.beats.length,
                threads: plot.threads.length,
                scenes: plot.scenes.length,
                plannedScenes: plot.scenes.filter(scene => scene.status === "Planned").length,
                completeScenes: plot.scenes.filter(scene => scene.status === "Complete").length
            };

        },


        formatDate(value) {

            if (!value) {
                return "Unavailable";
            }

            const parsed = new Date(value);

            if (Number.isNaN(parsed.getTime())) {
                return "Unavailable";
            }

            return parsed.toLocaleString();

        },


        closeModal() {

            if (!this.modalContainer) {
                return;
            }

            this.modalContainer.classList.remove("active");
            this.modalContainer.innerHTML = "";

        },


        bindModalBackdrop() {

            const backdrop = this.modalContainer?.querySelector(".project-modal-backdrop");

            if (!backdrop) {
                return;
            }

            backdrop.addEventListener("click", event => {
                if (event.target === backdrop) {
                    this.closeModal();
                }
            });

        },


        cloneData(value) {

            try {
                return JSON.parse(JSON.stringify(value));
            } catch (error) {
                console.error("Plot clone failed:", error);
                return null;
            }

        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
