/*
=========================================================
AUTHOROS
TIMELINE STUDIO MODULE
Milestone 09
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSTimeline = {

        name: "timeline",

        core: null,

        container: null,

        modalContainer: null,

        activeProjectId: null,

        selectedEntity: {
            type: "Overview",
            id: "overview"
        },

        uiState: {
            view: "list",
            search: "",
            type: "All",
            status: "All",
            importance: "All",
            eraId: "All",
            sequenceId: "All",
            datePrecision: "All",
            characterId: "All",
            locationId: "All",
            sort: "chronological"
        },

        eventStatuses: [
            "Planned",
            "Established",
            "Completed",
            "Archived"
        ],

        eraStatuses: [
            "Planned",
            "Established",
            "Completed",
            "Archived"
        ],

        sequenceStatuses: [
            "Planned",
            "Established",
            "Completed",
            "Archived"
        ],

        importanceLevels: [
            "Low",
            "Medium",
            "High",
            "Critical"
        ],

        datePrecisions: [
            "Exact",
            "Approximate",
            "Before",
            "After",
            "Range",
            "Unknown"
        ],

        eventTypes: [
            "Historical",
            "Plot",
            "Character",
            "Political",
            "War",
            "Discovery",
            "Relationship",
            "World",
            "Personal",
            "Custom"
        ],

        initialize(core) {

            this.core = core;
            this.modalContainer = document.getElementById("modal-container");

            this.core.events.on("navigation:changed", nav => {

                if (nav?.route !== "timeline") {
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

            const hydrated = this.ensureProjectTimelineShape(project);

            if (hydrated.changed) {
                this.persistProject(hydrated.project, "timeline-hydrate");
            }

            const currentProject = this.getProjectById(project.id) || hydrated.project;

            this.activeProjectId = currentProject.id;

            const timeline = this.getTimeline(currentProject);
            const warnings = this.validateChronology(currentProject, timeline);
            const filteredEvents = this.getFilteredEvents(currentProject, timeline);

            if (!this.isSelectedEntityPresent(timeline)) {
                this.selectedEntity = {
                    type: "Overview",
                    id: timeline.overview.id
                };
            }

            const selected = this.getSelectedEntity(timeline);

            container.innerHTML = `
                <section class="timeline-view library-view">

                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">TIMELINE STUDIO</p>
                            <h1>Timeline Studio</h1>
                            <p class="library-description">
                                Build chronology with explicit dates, ranges, and relative sequencing.
                            </p>
                            <p class="timeline-project-context">
                                Project: ${this.escapeHTML(this.getProjectTitle(currentProject))}
                            </p>
                        </div>

                        <div class="library-actions timeline-actions">
                            <button type="button" class="button button-primary" data-action="edit-timeline-overview">Edit Timeline Overview</button>
                            <button type="button" class="button button-secondary" data-action="new-timeline-era">+ Era</button>
                            <button type="button" class="button button-secondary" data-action="new-timeline-sequence">+ Sequence</button>
                            <button type="button" class="button button-secondary" data-action="new-timeline-event">+ Event</button>
                        </div>
                    </header>

                    ${this.renderControls(currentProject, timeline)}

                    ${warnings.length > 0 ? this.renderWarningPanel(warnings) : ""}

                    <div class="library-results-bar">
                        <span class="library-count">
                            ${filteredEvents.length}
                            ${filteredEvents.length === 1 ? "Event" : "Events"}
                        </span>
                        ${
                            this.hasActiveFilters()
                                ? `
                                    <span class="library-filter-state">
                                        Filtered from ${timeline.events.length} ${timeline.events.length === 1 ? "event" : "events"}
                                    </span>
                                `
                                : ""
                        }
                    </div>

                    ${this.renderSummaryCards(timeline, warnings)}

                    <div class="timeline-layout ${selected ? "with-detail" : ""}">
                        <div class="timeline-library-column">
                            ${this.renderMainContent(currentProject, timeline, filteredEvents)}
                        </div>

                        <aside class="timeline-detail-column" aria-label="Timeline detail panel">
                            ${selected ? this.renderDetail(currentProject, timeline, selected) : this.renderDetailEmptyState()}
                        </aside>
                    </div>

                </section>
            `;

            this.bindEvents(container, currentProject.id, timeline);

        },


        renderMissingProjectState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">◷</div>
                    <p class="eyebrow">TIMELINE STUDIO</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to plan chronology.</p>
                    <div class="manuscript-missing-actions">
                        <button type="button" class="button button-primary" data-action="open-story-library">Open Story Library</button>
                    </div>
                </section>
            `;

        },


        bindMissingProjectEvents(container) {

            container.querySelector('[data-action="open-story-library"]')?.addEventListener("click", event => {
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


        ensureProjectTimelineShape(project) {

            const next = this.cloneData(project);

            if (!next) {
                return { project, changed: false };
            }

            let changed = false;

            if (!next.story || typeof next.story !== "object") {
                next.story = {};
                changed = true;
            }

            const now = new Date().toISOString();

            if (!next.story.timeline || typeof next.story.timeline !== "object" || Array.isArray(next.story.timeline)) {

                const legacyEvents = Array.isArray(next.story.timeline)
                    ? next.story.timeline
                    : [];

                next.story.timeline = {
                    overview: {
                        id: AuthorOSHelpers.generateId("timeline_overview"),
                        projectId: next.id,
                        title: `${this.getProjectTitle(next)} Timeline`,
                        description: "",
                        calendarName: "",
                        startLabel: "",
                        endLabel: "",
                        notes: "",
                        createdAt: now,
                        updatedAt: now
                    },
                    eras: [],
                    sequences: [],
                    events: legacyEvents
                        .map((item, index) => this.normalizeEvent(
                            {
                                id: item?.id,
                                projectId: next.id,
                                title: String(item?.title || item?.name || "Timeline Event"),
                                description: String(item?.description || ""),
                                dateLabel: String(item?.date || ""),
                                dateValue: String(item?.dateValue || ""),
                                datePrecision: "Unknown",
                                order: index + 1,
                                status: "Planned",
                                importance: "Medium",
                                type: String(item?.type || "Custom"),
                                notes: "",
                                createdAt: item?.createdAt || now,
                                updatedAt: item?.updatedAt || now
                            },
                            next.id
                        ))
                        .filter(Boolean)
                };

                changed = true;
            }

            const timeline = next.story.timeline;

            if (!timeline.overview || typeof timeline.overview !== "object") {
                timeline.overview = {
                    id: AuthorOSHelpers.generateId("timeline_overview"),
                    projectId: next.id,
                    title: `${this.getProjectTitle(next)} Timeline`,
                    description: "",
                    calendarName: "",
                    startLabel: "",
                    endLabel: "",
                    notes: "",
                    createdAt: now,
                    updatedAt: now
                };
                changed = true;
            }

            const normalizedOverview = this.normalizeOverview(timeline.overview, next.id, this.getProjectTitle(next));

            if (JSON.stringify(timeline.overview) !== JSON.stringify(normalizedOverview)) {
                timeline.overview = normalizedOverview;
                changed = true;
            }

            changed = this.ensureEntityCollection(timeline, "eras", next.id, this.normalizeEra.bind(this)) || changed;
            changed = this.ensureEntityCollection(timeline, "sequences", next.id, this.normalizeSequence.bind(this)) || changed;
            changed = this.ensureEntityCollection(timeline, "events", next.id, this.normalizeEvent.bind(this)) || changed;

            if (!next.statistics || typeof next.statistics !== "object") {
                next.statistics = {};
                changed = true;
            }

            const eventCount = timeline.events.length;
            const eraCount = timeline.eras.length;

            if (Number(next.statistics.timeline || 0) !== eventCount) {
                next.statistics.timeline = eventCount;
                changed = true;
            }

            if (Number(next.statistics.timelineEras || 0) !== eraCount) {
                next.statistics.timelineEras = eraCount;
                changed = true;
            }

            return {
                project: next,
                changed
            };

        },


        ensureEntityCollection(timeline, key, projectId, normalizer) {

            if (!Array.isArray(timeline[key])) {
                timeline[key] = [];
                return true;
            }

            let changed = false;
            const seen = new Set();

            const normalized = timeline[key]
                .map(item => {

                    const normalizedItem = normalizer(item, projectId);

                    if (!normalizedItem) {
                        changed = true;
                        return null;
                    }

                    if (JSON.stringify(item) !== JSON.stringify(normalizedItem)) {
                        changed = true;
                    }

                    return normalizedItem;

                })
                .filter(Boolean)
                .sort((a, b) => Number(a.order || 0) - Number(b.order || 0))
                .map((item, index) => {

                    const nextItem = {
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

            timeline[key] = normalized;

            return changed;

        },


        getTimeline(project) {

            if (!project?.story?.timeline || typeof project.story.timeline !== "object" || Array.isArray(project.story.timeline)) {

                const now = new Date().toISOString();

                return {
                    overview: {
                        id: AuthorOSHelpers.generateId("timeline_overview"),
                        projectId: project?.id || "",
                        title: `${this.getProjectTitle(project)} Timeline`,
                        description: "",
                        calendarName: "",
                        startLabel: "",
                        endLabel: "",
                        notes: "",
                        createdAt: now,
                        updatedAt: now
                    },
                    eras: [],
                    sequences: [],
                    events: []
                };

            }

            return project.story.timeline;

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
                    : AuthorOSHelpers.generateId("timeline_overview"),
                projectId,
                title: String(candidate.title || `${projectTitle} Timeline`).trim() || `${projectTitle} Timeline`,
                description: String(candidate.description || ""),
                calendarName: String(candidate.calendarName || ""),
                startLabel: String(candidate.startLabel || ""),
                endLabel: String(candidate.endLabel || ""),
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt
            };

        },


        normalizeEra(candidate, projectId) {

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

            const status = this.eraStatuses.includes(String(candidate.status || "").trim())
                ? String(candidate.status).trim()
                : "Planned";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("era"),
                projectId,
                title: String(candidate.title || "Untitled Era").trim() || "Untitled Era",
                description: String(candidate.description || ""),
                start: String(candidate.start || ""),
                end: String(candidate.end || ""),
                order: this.normalizeOrder(candidate.order),
                status,
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeSequence(candidate, projectId) {

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

            const status = this.sequenceStatuses.includes(String(candidate.status || "").trim())
                ? String(candidate.status).trim()
                : "Planned";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("sequence"),
                projectId,
                title: String(candidate.title || "Untitled Sequence").trim() || "Untitled Sequence",
                description: String(candidate.description || ""),
                order: this.normalizeOrder(candidate.order),
                status,
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeEvent(candidate, projectId) {

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

            const status = this.eventStatuses.includes(String(candidate.status || "").trim())
                ? String(candidate.status).trim()
                : "Planned";

            const importance = this.importanceLevels.includes(String(candidate.importance || "").trim())
                ? String(candidate.importance).trim()
                : "Medium";

            const datePrecision = this.datePrecisions.includes(String(candidate.datePrecision || "").trim())
                ? String(candidate.datePrecision).trim()
                : "Unknown";

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("timeline_event"),
                projectId,
                title: String(candidate.title || "Untitled Event").trim() || "Untitled Event",
                description: String(candidate.description || ""),
                dateLabel: String(candidate.dateLabel || ""),
                dateValue: String(candidate.dateValue || ""),
                endDateValue: String(candidate.endDateValue || ""),
                datePrecision,
                relativeKind: String(candidate.relativeKind || "").trim(),
                relativeTargetType: String(candidate.relativeTargetType || "").trim(),
                relativeTargetId: String(candidate.relativeTargetId || "").trim(),
                eraId: String(candidate.eraId || "").trim(),
                sequenceId: String(candidate.sequenceId || "").trim(),
                type: String(candidate.type || "Custom").trim() || "Custom",
                order: this.normalizeOrder(candidate.order),
                status,
                importance,
                notes: String(candidate.notes || ""),
                chapterId: String(candidate.chapterId || "").trim(),
                plotArcId: String(candidate.plotArcId || "").trim(),
                plotBeatId: String(candidate.plotBeatId || "").trim(),
                plotSceneId: String(candidate.plotSceneId || "").trim(),
                characterIds: Array.isArray(candidate.characterIds)
                    ? candidate.characterIds.map(id => String(id || "").trim()).filter(Boolean)
                    : [],
                worldIds: Array.isArray(candidate.worldIds)
                    ? candidate.worldIds.map(id => String(id || "").trim()).filter(Boolean)
                    : [],
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
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


        renderControls(project, timeline) {

            return `
                <div class="library-controls timeline-controls">

                    <div class="library-search">
                        <label for="timeline-search-input" class="visually-hidden">Search timeline</label>
                        <span class="library-search-icon" aria-hidden="true">⌕</span>
                        <input
                            id="timeline-search-input"
                            type="search"
                            class="library-search-input"
                            placeholder="Search timeline..."
                            autocomplete="off"
                            value="${this.escapeHTML(this.uiState.search)}"
                        />
                        ${
                            this.uiState.search
                                ? `<button type="button" class="library-search-clear" data-action="clear-timeline-search" aria-label="Clear search">×</button>`
                                : ""
                        }
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-view-filter">View</label>
                        <select id="timeline-view-filter" class="library-filter-select">
                            <option value="list" ${this.uiState.view === "list" ? "selected" : ""}>Event List</option>
                            <option value="chronological" ${this.uiState.view === "chronological" ? "selected" : ""}>Chronological</option>
                            <option value="eras" ${this.uiState.view === "eras" ? "selected" : ""}>Era View</option>
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-type-filter">Type</label>
                        <select id="timeline-type-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.type === "All" ? "selected" : ""}>All types</option>
                            ${this.getEventTypes(timeline.events).map(type => `
                                <option value="${this.escapeHTML(type)}" ${this.uiState.type === type ? "selected" : ""}>${this.escapeHTML(type)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-status-filter">Status</label>
                        <select id="timeline-status-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.status === "All" ? "selected" : ""}>All statuses</option>
                            ${this.eventStatuses.map(value => `
                                <option value="${this.escapeHTML(value)}" ${this.uiState.status === value ? "selected" : ""}>${this.escapeHTML(value)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-importance-filter">Importance</label>
                        <select id="timeline-importance-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.importance === "All" ? "selected" : ""}>All levels</option>
                            ${this.importanceLevels.map(value => `
                                <option value="${this.escapeHTML(value)}" ${this.uiState.importance === value ? "selected" : ""}>${this.escapeHTML(value)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-era-filter">Era</label>
                        <select id="timeline-era-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.eraId === "All" ? "selected" : ""}>All eras</option>
                            ${timeline.eras.map(era => `
                                <option value="${this.escapeHTML(era.id)}" ${this.uiState.eraId === era.id ? "selected" : ""}>${this.escapeHTML(era.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-sequence-filter">Sequence</label>
                        <select id="timeline-sequence-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.sequenceId === "All" ? "selected" : ""}>All sequences</option>
                            ${timeline.sequences.map(sequence => `
                                <option value="${this.escapeHTML(sequence.id)}" ${this.uiState.sequenceId === sequence.id ? "selected" : ""}>${this.escapeHTML(sequence.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-date-precision-filter">Date</label>
                        <select id="timeline-date-precision-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.datePrecision === "All" ? "selected" : ""}>All precision</option>
                            ${this.datePrecisions.map(value => `
                                <option value="${this.escapeHTML(value)}" ${this.uiState.datePrecision === value ? "selected" : ""}>${this.escapeHTML(value)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-character-filter">Character</label>
                        <select id="timeline-character-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.characterId === "All" ? "selected" : ""}>All characters</option>
                            ${this.getProjectCharacters(project).map(character => `
                                <option value="${this.escapeHTML(character.id)}" ${this.uiState.characterId === character.id ? "selected" : ""}>${this.escapeHTML(this.getCharacterName(character))}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-location-filter">Location</label>
                        <select id="timeline-location-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.locationId === "All" ? "selected" : ""}>All locations</option>
                            ${this.getProjectLocations(project).map(location => `
                                <option value="${this.escapeHTML(location.id)}" ${this.uiState.locationId === location.id ? "selected" : ""}>${this.escapeHTML(location.title)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="timeline-sort-filter">Sort</label>
                        <select id="timeline-sort-filter" class="library-filter-select">
                            <option value="chronological" ${this.uiState.sort === "chronological" ? "selected" : ""}>Chronological</option>
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently created</option>
                            <option value="title-asc" ${this.uiState.sort === "title-asc" ? "selected" : ""}>Title A-Z</option>
                            <option value="title-desc" ${this.uiState.sort === "title-desc" ? "selected" : ""}>Title Z-A</option>
                            <option value="importance-desc" ${this.uiState.sort === "importance-desc" ? "selected" : ""}>Importance</option>
                            <option value="order-asc" ${this.uiState.sort === "order-asc" ? "selected" : ""}>Manual order</option>
                        </select>
                    </div>

                    ${
                        this.hasActiveFilters()
                            ? `<button type="button" class="library-clear-filters" data-action="clear-timeline-filters">Clear filters</button>`
                            : ""
                    }

                </div>
            `;

        },


        renderWarningPanel(warnings) {

            return `
                <section class="timeline-warning-panel" aria-live="polite">
                    <h2>Chronology Warnings</h2>
                    <ul class="timeline-warning-list">
                        ${warnings.map(warning => `
                            <li>
                                <strong>${this.escapeHTML(warning.code)}</strong>
                                <p>${this.escapeHTML(warning.message)}</p>
                                <p>${this.escapeHTML(warning.entities.join(" | "))}</p>
                            </li>
                        `).join("")}
                    </ul>
                </section>
            `;

        },


        renderSummaryCards(timeline, warnings) {

            const events = timeline.events;
            const planned = events.filter(event => event.status === "Planned").length;
            const completed = events.filter(event => event.status === "Completed").length;

            return `
                <section class="timeline-summary-grid" aria-label="Timeline planning summary">
                    <article class="timeline-summary-card">
                        <h3>Events</h3>
                        <p>${events.length}</p>
                    </article>
                    <article class="timeline-summary-card">
                        <h3>Eras</h3>
                        <p>${timeline.eras.length}</p>
                    </article>
                    <article class="timeline-summary-card">
                        <h3>Sequences</h3>
                        <p>${timeline.sequences.length}</p>
                    </article>
                    <article class="timeline-summary-card">
                        <h3>Planned</h3>
                        <p>${planned}</p>
                    </article>
                    <article class="timeline-summary-card">
                        <h3>Completed</h3>
                        <p>${completed}</p>
                    </article>
                    <article class="timeline-summary-card">
                        <h3>Warnings</h3>
                        <p>${warnings.length}</p>
                        <small>${warnings.length === 0 ? "No chronology conflicts" : "Review chronology panel"}</small>
                    </article>
                </section>
            `;

        },


        renderMainContent(project, timeline, filteredEvents) {

            if (!timeline.events.length && !timeline.eras.length && !timeline.sequences.length) {
                return this.renderEmptyState(false);
            }

            if (!filteredEvents.length) {
                return this.renderEmptyState(true);
            }

            if (this.uiState.view === "chronological") {
                return this.renderChronologicalView(project, timeline, filteredEvents);
            }

            if (this.uiState.view === "eras") {
                return this.renderEraView(project, timeline, filteredEvents);
            }

            return this.renderEventList(project, timeline, filteredEvents);

        },


        renderEmptyState(hasData) {

            if (hasData) {
                return `
                    <section class="library-empty-state">
                        <div class="empty-state-icon">⌕</div>
                        <h2>No timeline events match your filters</h2>
                        <p>Adjust search, filters, or sorting.</p>
                        <button type="button" class="button button-secondary" data-action="clear-timeline-filters">Clear filters</button>
                    </section>
                `;
            }

            return `
                <section class="library-empty-state">
                    <div class="empty-state-icon">◷</div>
                    <h2>No timeline data yet</h2>
                    <p>Create your timeline overview, then add eras, sequences, and events.</p>
                    <button type="button" class="button button-primary" data-action="new-timeline-event">Add First Event</button>
                </section>
            `;

        },


        renderEventList(project, timeline, events) {

            return `
                <div class="project-grid timeline-grid">
                    ${events.map(event => this.renderEventCard(project, timeline, event)).join("")}
                </div>
            `;

        },


        renderChronologicalView(project, timeline, events) {

            const grouped = this.groupEventsByChronology(project, timeline, events);

            return `
                <div class="timeline-chronology-list">
                    ${grouped.map(group => `
                        <section class="timeline-chronology-group">
                            <h2>${this.escapeHTML(group.label)}</h2>
                            <div class="project-grid timeline-grid">
                                ${group.events.map(event => this.renderEventCard(project, timeline, event)).join("")}
                            </div>
                        </section>
                    `).join("")}
                </div>
            `;

        },


        renderEraView(project, timeline, events) {

            const eraMap = new Map(timeline.eras.map(era => [era.id, era]));
            const bucket = new Map();

            timeline.eras.forEach(era => {
                bucket.set(era.id, []);
            });

            const unassigned = [];

            events.forEach(event => {

                const eraId = String(event.eraId || "").trim();

                if (eraId && bucket.has(eraId)) {
                    bucket.get(eraId).push(event);
                    return;
                }

                unassigned.push(event);

            });

            return `
                <div class="timeline-era-list">
                    ${timeline.eras.map(era => `
                        <section class="timeline-era-group">
                            <header>
                                <h2>${this.escapeHTML(era.title)}</h2>
                                <p>${this.escapeHTML(this.describeEraRange(era))}</p>
                            </header>
                            <div class="project-grid timeline-grid">
                                ${(bucket.get(era.id) || []).map(event => this.renderEventCard(project, timeline, event)).join("") || "<p class=\"timeline-era-empty\">No events assigned.</p>"}
                            </div>
                        </section>
                    `).join("")}
                    <section class="timeline-era-group">
                        <header>
                            <h2>Unassigned Era</h2>
                            <p>Events not linked to an era.</p>
                        </header>
                        <div class="project-grid timeline-grid">
                            ${unassigned.map(event => this.renderEventCard(project, timeline, event)).join("") || "<p class=\"timeline-era-empty\">No unassigned events.</p>"}
                        </div>
                    </section>
                </div>
            `;

        },


        renderEventCard(project, timeline, event) {

            const selected = this.selectedEntity.type === "Event" && this.selectedEntity.id === event.id;

            const era = timeline.eras.find(item => item.id === event.eraId) || null;
            const sequence = timeline.sequences.find(item => item.id === event.sequenceId) || null;

            return `
                <article class="project-card timeline-card ${selected ? "selected" : ""}">
                    <div class="project-card-body">
                        <header class="timeline-card-header">
                            <h2>${this.escapeHTML(event.title)}</h2>
                            <p class="timeline-card-updated">Updated ${this.escapeHTML(this.formatDate(event.updatedAt))}</p>
                        </header>

                        <dl class="timeline-card-meta">
                            <div>
                                <dt>Date</dt>
                                <dd>${this.escapeHTML(this.getEventDateLabel(event))}</dd>
                            </div>
                            <div>
                                <dt>Precision</dt>
                                <dd>${this.escapeHTML(event.datePrecision)}</dd>
                            </div>
                            <div>
                                <dt>Status</dt>
                                <dd>${this.escapeHTML(event.status)}</dd>
                            </div>
                            <div>
                                <dt>Type</dt>
                                <dd>${this.escapeHTML(event.type)}</dd>
                            </div>
                            <div>
                                <dt>Importance</dt>
                                <dd>${this.escapeHTML(event.importance)}</dd>
                            </div>
                            <div>
                                <dt>Order</dt>
                                <dd>${this.escapeHTML(String(event.order || 1))}</dd>
                            </div>
                        </dl>

                        <p class="timeline-card-summary">${this.escapeHTML(String(event.description || "").trim() || "No description yet.")}</p>

                        <p class="timeline-card-links">
                            Era: ${this.escapeHTML(era ? era.title : event.eraId ? "Missing era reference" : "Unassigned")}
                            | Sequence: ${this.escapeHTML(sequence ? sequence.title : event.sequenceId ? "Missing sequence reference" : "Unassigned")}
                        </p>

                        <div class="idea-card-actions">
                            <button type="button" class="button button-secondary" data-action="open-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Open</button>
                            <button type="button" class="button button-secondary" data-action="edit-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Edit</button>
                            <button type="button" class="button button-secondary" data-action="duplicate-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Duplicate</button>
                            <button type="button" class="button button-secondary" data-action="move-timeline-event-up" data-event-id="${this.escapeHTML(event.id)}">Move Up</button>
                            <button type="button" class="button button-secondary" data-action="move-timeline-event-down" data-event-id="${this.escapeHTML(event.id)}">Move Down</button>
                            ${
                                event.status === "Archived"
                                    ? `<button type="button" class="button button-secondary" data-action="restore-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Restore</button>`
                                    : `<button type="button" class="button button-secondary" data-action="archive-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Archive</button>`
                            }
                            <button type="button" class="button button-danger" data-action="delete-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Delete</button>
                        </div>
                    </div>
                </article>
            `;

        },


        renderDetailEmptyState() {

            return `
                <section class="idea-detail-empty-state">
                    <h3>Select a timeline item</h3>
                    <p>Open an event, era, sequence, or timeline overview to inspect details.</p>
                </section>
            `;

        },


        renderDetail(project, timeline, selected) {

            if (selected.type === "Overview") {
                return this.renderOverviewDetail(timeline.overview);
            }

            if (selected.type === "Era") {
                return this.renderEraDetail(timeline, selected.id);
            }

            if (selected.type === "Sequence") {
                return this.renderSequenceDetail(timeline, selected.id);
            }

            if (selected.type === "Event") {
                return this.renderEventDetail(project, timeline, selected.id);
            }

            return this.renderDetailEmptyState();

        },


        renderOverviewDetail(overview) {

            return `
                <article class="idea-detail-card timeline-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">TIMELINE OVERVIEW</p>
                        <h2>${this.escapeHTML(overview.title)}</h2>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Calendar</dt><dd>${this.escapeHTML(String(overview.calendarName || "").trim() || "Unspecified")}</dd></div>
                        <div><dt>Start Label</dt><dd>${this.escapeHTML(String(overview.startLabel || "").trim() || "Unspecified")}</dd></div>
                        <div><dt>End Label</dt><dd>${this.escapeHTML(String(overview.endLabel || "").trim() || "Unspecified")}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Description", overview.description)}
                    ${this.renderDetailTextBlock("Notes", overview.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-timeline-overview">Edit Overview</button>
                    </div>
                </article>
            `;

        },


        renderEraDetail(timeline, eraId) {

            const era = timeline.eras.find(item => item.id === eraId);

            if (!era) {
                return this.renderDetailEmptyState();
            }

            const eventCount = timeline.events.filter(event => event.eraId === era.id).length;

            return `
                <article class="idea-detail-card timeline-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">TIMELINE ERA</p>
                        <h2>${this.escapeHTML(era.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(era.status)}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Range</dt><dd>${this.escapeHTML(this.describeEraRange(era))}</dd></div>
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(era.order || 1))}</dd></div>
                        <div><dt>Events</dt><dd>${this.escapeHTML(String(eventCount))}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Description", era.description)}
                    ${this.renderDetailTextBlock("Notes", era.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-timeline-era" data-era-id="${this.escapeHTML(era.id)}">Edit Era</button>
                    </div>
                </article>
            `;

        },


        renderSequenceDetail(timeline, sequenceId) {

            const sequence = timeline.sequences.find(item => item.id === sequenceId);

            if (!sequence) {
                return this.renderDetailEmptyState();
            }

            const eventCount = timeline.events.filter(event => event.sequenceId === sequence.id).length;

            return `
                <article class="idea-detail-card timeline-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">TIMELINE SEQUENCE</p>
                        <h2>${this.escapeHTML(sequence.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(sequence.status)}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(sequence.order || 1))}</dd></div>
                        <div><dt>Events</dt><dd>${this.escapeHTML(String(eventCount))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(sequence.updatedAt))}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Description", sequence.description)}
                    ${this.renderDetailTextBlock("Notes", sequence.notes)}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-timeline-sequence" data-sequence-id="${this.escapeHTML(sequence.id)}">Edit Sequence</button>
                    </div>
                </article>
            `;

        },


        renderEventDetail(project, timeline, eventId) {

            const event = timeline.events.find(item => item.id === eventId);

            if (!event) {
                return this.renderDetailEmptyState();
            }

            const era = timeline.eras.find(item => item.id === event.eraId);
            const sequence = timeline.sequences.find(item => item.id === event.sequenceId);

            const characters = this.resolveCharacterLabels(project, event.characterIds);
            const locations = this.resolveWorldLabels(project, event.worldIds);

            const chapter = this.getChapterById(project, event.chapterId);
            const plot = this.getPlot(project);
            const plotArc = plot.arcs.find(item => item.id === event.plotArcId) || null;
            const plotBeat = plot.beats.find(item => item.id === event.plotBeatId) || null;
            const plotScene = plot.scenes.find(item => item.id === event.plotSceneId) || null;

            const relativeLabel = this.getRelativeRelationshipLabel(timeline, event);

            return `
                <article class="idea-detail-card timeline-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">TIMELINE EVENT</p>
                        <h2>${this.escapeHTML(event.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(event.type)} | ${this.escapeHTML(event.importance)} | ${this.escapeHTML(event.status)}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Date</dt><dd>${this.escapeHTML(this.getEventDateLabel(event))}</dd></div>
                        <div><dt>Precision</dt><dd>${this.escapeHTML(event.datePrecision)}</dd></div>
                        <div><dt>Order</dt><dd>${this.escapeHTML(String(event.order || 1))}</dd></div>
                    </dl>

                    <dl class="idea-detail-meta">
                        <div><dt>Era</dt><dd>${this.escapeHTML(era ? era.title : event.eraId ? "Missing era reference" : "Unassigned")}</dd></div>
                        <div><dt>Sequence</dt><dd>${this.escapeHTML(sequence ? sequence.title : event.sequenceId ? "Missing sequence reference" : "Unassigned")}</dd></div>
                        <div><dt>Relative</dt><dd>${this.escapeHTML(relativeLabel)}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Description", event.description)}
                    ${this.renderDetailTextBlock("Notes", event.notes)}
                    ${this.renderDetailTextBlock("Characters", characters.length ? characters.join(", ") : "None")}
                    ${this.renderDetailTextBlock("Locations", locations.length ? locations.join(", ") : "None")}
                    ${this.renderDetailTextBlock("Chapter", chapter ? chapter.title : event.chapterId ? "Missing chapter reference" : "Unlinked")}
                    ${this.renderDetailTextBlock("Plot Arc", plotArc ? plotArc.title : event.plotArcId ? "Missing arc reference" : "Unlinked")}
                    ${this.renderDetailTextBlock("Plot Beat", plotBeat ? plotBeat.title : event.plotBeatId ? "Missing beat reference" : "Unlinked")}
                    ${this.renderDetailTextBlock("Plot Scene", plotScene ? plotScene.title : event.plotSceneId ? "Missing scene reference" : "Unlinked")}

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-timeline-event" data-event-id="${this.escapeHTML(event.id)}">Edit</button>
                        ${event.chapterId ? `<button type="button" class="button button-secondary" data-action="open-timeline-chapter" data-chapter-id="${this.escapeHTML(event.chapterId)}">Open Chapter</button>` : ""}
                        ${(event.characterIds || []).length ? `<button type="button" class="button button-secondary" data-action="open-timeline-character">Open Character Studio</button>` : ""}
                        ${(event.worldIds || []).length ? `<button type="button" class="button button-secondary" data-action="open-timeline-world">Open World Studio</button>` : ""}
                        ${(event.plotArcId || event.plotBeatId || event.plotSceneId) ? `<button type="button" class="button button-secondary" data-action="open-timeline-plot">Open Plot Studio</button>` : ""}
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


        bindEvents(container, projectId, timeline) {

            container.querySelector('[data-action="edit-timeline-overview"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showOverviewModal(projectId);
            });

            container.querySelector('[data-action="new-timeline-era"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showEraModal(projectId);
            });

            container.querySelector('[data-action="new-timeline-sequence"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.showSequenceModal(projectId);
            });

            container.querySelectorAll('[data-action="new-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showEventModal(projectId);
                });
            });

            container.querySelector("#timeline-search-input")?.addEventListener("input", event => {
                this.uiState.search = String(event.target.value || "");
                this.render(this.container);
            });

            container.querySelector('[data-action="clear-timeline-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.search = "";
                this.render(this.container);
            });

            [
                ["#timeline-view-filter", "view", "list"],
                ["#timeline-type-filter", "type", "All"],
                ["#timeline-status-filter", "status", "All"],
                ["#timeline-importance-filter", "importance", "All"],
                ["#timeline-era-filter", "eraId", "All"],
                ["#timeline-sequence-filter", "sequenceId", "All"],
                ["#timeline-date-precision-filter", "datePrecision", "All"],
                ["#timeline-character-filter", "characterId", "All"],
                ["#timeline-location-filter", "locationId", "All"],
                ["#timeline-sort-filter", "sort", "chronological"]
            ].forEach(([selector, key, fallback]) => {

                const input = container.querySelector(selector);

                input?.addEventListener("change", () => {
                    this.uiState[key] = String(input.value || fallback);
                    this.render(this.container);
                });

            });

            container.querySelectorAll('[data-action="clear-timeline-filters"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.clearFilters();
                });
            });

            container.querySelectorAll('[data-action="open-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.selectedEntity = {
                        type: "Event",
                        id: button.dataset.eventId
                    };
                    this.render(this.container);
                });
            });

            container.querySelectorAll('[data-action="edit-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showEventModal(projectId, button.dataset.eventId);
                });
            });

            container.querySelectorAll('[data-action="edit-timeline-era"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showEraModal(projectId, button.dataset.eraId);
                });
            });

            container.querySelectorAll('[data-action="edit-timeline-sequence"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showSequenceModal(projectId, button.dataset.sequenceId);
                });
            });

            container.querySelectorAll('[data-action="duplicate-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.duplicateEvent(projectId, button.dataset.eventId);
                });
            });

            container.querySelectorAll('[data-action="archive-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.archiveEvent(projectId, button.dataset.eventId);
                });
            });

            container.querySelectorAll('[data-action="restore-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.restoreEvent(projectId, button.dataset.eventId);
                });
            });

            container.querySelectorAll('[data-action="delete-timeline-event"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.confirmDeleteEvent(projectId, button.dataset.eventId);
                });
            });

            container.querySelectorAll('[data-action="move-timeline-event-up"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.moveEvent(projectId, button.dataset.eventId, -1);
                });
            });

            container.querySelectorAll('[data-action="move-timeline-event-down"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.moveEvent(projectId, button.dataset.eventId, 1);
                });
            });

            container.querySelector('[data-action="open-timeline-character"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.navigation.navigate("characters");
            });

            container.querySelector('[data-action="open-timeline-world"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.navigation.navigate("world");
            });

            container.querySelector('[data-action="open-timeline-plot"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.navigation.navigate("plot");
            });

            container.querySelector('[data-action="open-timeline-chapter"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.openLinkedChapter(projectId, event.currentTarget.dataset.chapterId);
            });

            container.querySelectorAll('[data-action="open-era-detail"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.selectedEntity = {
                        type: "Era",
                        id: button.dataset.eraId
                    };
                    this.render(this.container);
                });
            });

            container.querySelectorAll('[data-action="open-sequence-detail"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.selectedEntity = {
                        type: "Sequence",
                        id: button.dataset.sequenceId
                    };
                    this.render(this.container);
                });
            });

        },


        hasActiveFilters() {

            return Boolean(
                this.uiState.search.trim() ||
                this.uiState.type !== "All" ||
                this.uiState.status !== "All" ||
                this.uiState.importance !== "All" ||
                this.uiState.eraId !== "All" ||
                this.uiState.sequenceId !== "All" ||
                this.uiState.datePrecision !== "All" ||
                this.uiState.characterId !== "All" ||
                this.uiState.locationId !== "All" ||
                this.uiState.sort !== "chronological" ||
                this.uiState.view !== "list"
            );

        },


        clearFilters() {

            this.uiState = {
                view: "list",
                search: "",
                type: "All",
                status: "All",
                importance: "All",
                eraId: "All",
                sequenceId: "All",
                datePrecision: "All",
                characterId: "All",
                locationId: "All",
                sort: "chronological"
            };

            this.render(this.container);

        },


        getFilteredEvents(project, timeline) {

            let events = Array.isArray(timeline.events)
                ? [...timeline.events]
                : [];

            if (this.uiState.type !== "All") {
                events = events.filter(event => event.type === this.uiState.type);
            }

            if (this.uiState.status !== "All") {
                events = events.filter(event => event.status === this.uiState.status);
            }

            if (this.uiState.importance !== "All") {
                events = events.filter(event => event.importance === this.uiState.importance);
            }

            if (this.uiState.eraId !== "All") {
                events = events.filter(event => String(event.eraId || "") === this.uiState.eraId);
            }

            if (this.uiState.sequenceId !== "All") {
                events = events.filter(event => String(event.sequenceId || "") === this.uiState.sequenceId);
            }

            if (this.uiState.datePrecision !== "All") {
                events = events.filter(event => String(event.datePrecision || "") === this.uiState.datePrecision);
            }

            if (this.uiState.characterId !== "All") {
                events = events.filter(event => Array.isArray(event.characterIds) && event.characterIds.includes(this.uiState.characterId));
            }

            if (this.uiState.locationId !== "All") {
                events = events.filter(event => Array.isArray(event.worldIds) && event.worldIds.includes(this.uiState.locationId));
            }

            const search = this.uiState.search.trim().toLowerCase();

            if (search) {

                const eraMap = new Map(timeline.eras.map(era => [era.id, era.title]));
                const sequenceMap = new Map(timeline.sequences.map(sequence => [sequence.id, sequence.title]));

                events = events.filter(event => {

                    const characterNames = this.resolveCharacterLabels(project, event.characterIds).join(" ");
                    const locationNames = this.resolveWorldLabels(project, event.worldIds).join(" ");

                    const searchable = [
                        event.title,
                        event.description,
                        event.dateLabel,
                        event.dateValue,
                        event.endDateValue,
                        event.type,
                        event.status,
                        event.importance,
                        event.notes,
                        eraMap.get(event.eraId) || "",
                        sequenceMap.get(event.sequenceId) || "",
                        characterNames,
                        locationNames
                    ]
                        .filter(Boolean)
                        .join(" ")
                        .toLowerCase();

                    return searchable.includes(search);

                });

            }

            return this.sortEvents(timeline, events);

        },


        sortEvents(timeline, events) {

            const list = [...events];
            const dateValue = value => {
                const time = Date.parse(value || "");
                return Number.isNaN(time) ? 0 : time;
            };

            const importanceRank = {
                Low: 1,
                Medium: 2,
                High: 3,
                Critical: 4
            };

            if (this.uiState.sort === "updated-desc") {
                return list.sort((left, right) => dateValue(right.updatedAt) - dateValue(left.updatedAt));
            }

            if (this.uiState.sort === "created-desc") {
                return list.sort((left, right) => dateValue(right.createdAt) - dateValue(left.createdAt));
            }

            if (this.uiState.sort === "title-asc") {
                return list.sort((left, right) => this.getEntityTitle(left).localeCompare(this.getEntityTitle(right), undefined, { sensitivity: "base" }));
            }

            if (this.uiState.sort === "title-desc") {
                return list.sort((left, right) => this.getEntityTitle(right).localeCompare(this.getEntityTitle(left), undefined, { sensitivity: "base" }));
            }

            if (this.uiState.sort === "importance-desc") {
                return list.sort((left, right) => {

                    const diff = (importanceRank[right.importance] || 0) - (importanceRank[left.importance] || 0);

                    if (diff !== 0) {
                        return diff;
                    }

                    return dateValue(right.updatedAt) - dateValue(left.updatedAt);

                });
            }

            if (this.uiState.sort === "order-asc") {
                return list.sort((left, right) => {

                    const orderDiff = Number(left.order || 0) - Number(right.order || 0);

                    if (orderDiff !== 0) {
                        return orderDiff;
                    }

                    return dateValue(right.updatedAt) - dateValue(left.updatedAt);

                });
            }

            return this.sortEventsChronologically(timeline, list);

        },


        sortEventsChronologically(timeline, events) {

            const byId = new Map(events.map(event => [event.id, event]));

            return [...events].sort((left, right) => {

                const leftKey = this.getChronologyKey(timeline, left, byId);
                const rightKey = this.getChronologyKey(timeline, right, byId);

                if (leftKey.group !== rightKey.group) {
                    return leftKey.group - rightKey.group;
                }

                if (leftKey.value !== rightKey.value) {
                    return leftKey.value - rightKey.value;
                }

                if (leftKey.tie !== rightKey.tie) {
                    return leftKey.tie - rightKey.tie;
                }

                return this.getEntityTitle(left).localeCompare(this.getEntityTitle(right), undefined, { sensitivity: "base" });

            });

        },


        getChronologyKey(timeline, event, byId) {

            const precision = String(event.datePrecision || "Unknown");

            const base = this.parseDateNumber(event.dateValue);
            const end = this.parseDateNumber(event.endDateValue);

            if (precision === "Exact" && base !== null) {
                return { group: 1, value: base, tie: Number(event.order || 0) };
            }

            if (precision === "Range" && base !== null) {
                return { group: 2, value: base, tie: end !== null ? end : Number(event.order || 0) };
            }

            if (precision === "Approximate" && base !== null) {
                return { group: 3, value: base, tie: Number(event.order || 0) };
            }

            if ((precision === "Before" || precision === "After") && event.relativeTargetType === "event") {

                const target = byId.get(event.relativeTargetId);

                if (target) {

                    const targetKey = this.getChronologyKey(timeline, target, byId);

                    if (targetKey.group < 9) {
                        return {
                            group: 4,
                            value: targetKey.value + (precision === "Before" ? -0.1 : 0.1),
                            tie: Number(event.order || 0)
                        };
                    }

                }

            }

            if (precision === "Before" && base !== null) {
                return { group: 4, value: base - 0.1, tie: Number(event.order || 0) };
            }

            if (precision === "After" && base !== null) {
                return { group: 4, value: base + 0.1, tie: Number(event.order || 0) };
            }

            return {
                group: 9,
                value: Number(event.order || 0),
                tie: Number(event.order || 0)
            };

        },


        parseDateNumber(value) {

            const raw = String(value || "").trim();

            if (!raw) {
                return null;
            }

            const numeric = Number(raw);

            if (Number.isFinite(numeric)) {
                return numeric;
            }

            const dateTime = Date.parse(raw);

            if (!Number.isNaN(dateTime)) {
                return dateTime;
            }

            return null;

        },


        groupEventsByChronology(project, timeline, events) {

            const sorted = this.sortEventsChronologically(timeline, events);
            const groups = new Map();

            sorted.forEach(event => {

                const label = this.getChronologyGroupLabel(timeline, event);

                if (!groups.has(label)) {
                    groups.set(label, []);
                }

                groups.get(label).push(event);

            });

            return Array.from(groups.entries()).map(([label, list]) => ({
                label,
                events: list
            }));

        },


        getChronologyGroupLabel(timeline, event) {

            if (event.datePrecision === "Unknown") {
                return "Unknown Date";
            }

            if (event.datePrecision === "Range") {
                return `Range: ${this.getEventDateLabel(event)}`;
            }

            if (event.datePrecision === "Before" || event.datePrecision === "After") {
                return `${event.datePrecision}: ${this.getEventDateLabel(event)}`;
            }

            const era = timeline.eras.find(item => item.id === event.eraId);

            if (era) {
                return `Era: ${era.title}`;
            }

            return this.getEventDateLabel(event);

        },


        getEventDateLabel(event) {

            const precision = String(event.datePrecision || "Unknown");
            const dateLabel = String(event.dateLabel || "").trim();
            const dateValue = String(event.dateValue || "").trim();
            const endDateValue = String(event.endDateValue || "").trim();

            if (precision === "Unknown") {
                return dateLabel || "Unknown date";
            }

            if (precision === "Range") {
                if (dateValue && endDateValue) {
                    return `${dateValue} - ${endDateValue}`;
                }
                return dateLabel || "Range (incomplete)";
            }

            if (precision === "Before") {
                return dateValue ? `Before ${dateValue}` : dateLabel || "Before (unspecified)";
            }

            if (precision === "After") {
                return dateValue ? `After ${dateValue}` : dateLabel || "After (unspecified)";
            }

            if (precision === "Approximate") {
                return dateValue ? `Approx. ${dateValue}` : dateLabel || "Approximate date";
            }

            return dateValue || dateLabel || "Unspecified";

        },


        getSelectedEntity(timeline) {

            if (this.selectedEntity.type === "Overview") {
                return {
                    type: "Overview",
                    id: timeline.overview.id
                };
            }

            if (this.selectedEntity.type === "Event") {
                return timeline.events.find(event => event.id === this.selectedEntity.id)
                    ? this.selectedEntity
                    : null;
            }

            if (this.selectedEntity.type === "Era") {
                return timeline.eras.find(era => era.id === this.selectedEntity.id)
                    ? this.selectedEntity
                    : null;
            }

            if (this.selectedEntity.type === "Sequence") {
                return timeline.sequences.find(sequence => sequence.id === this.selectedEntity.id)
                    ? this.selectedEntity
                    : null;
            }

            return null;

        },


        isSelectedEntityPresent(timeline) {

            if (this.selectedEntity.type === "Overview") {
                return true;
            }

            if (this.selectedEntity.type === "Event") {
                return timeline.events.some(event => event.id === this.selectedEntity.id);
            }

            if (this.selectedEntity.type === "Era") {
                return timeline.eras.some(era => era.id === this.selectedEntity.id);
            }

            if (this.selectedEntity.type === "Sequence") {
                return timeline.sequences.some(sequence => sequence.id === this.selectedEntity.id);
            }

            return false;

        },


        showOverviewModal(projectId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const timeline = this.getTimeline(project);
            const overview = timeline.overview;

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="timeline-overview-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">TIMELINE STUDIO</p>
                                <h2 id="timeline-overview-title">Timeline Overview</h2>
                                <p>Set chronology context and calendar labels.</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-timeline-modal" aria-label="Close timeline overview form">×</button>
                        </header>

                        <form id="timeline-overview-form" class="project-form" novalidate>
                            <div class="project-form-grid">

                                <label class="form-field form-field-wide" for="timeline-overview-title-input">
                                    <span>Title *</span>
                                    <input id="timeline-overview-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(overview.title || `${this.getProjectTitle(project)} Timeline`)}" />
                                </label>

                                <label class="form-field form-field-wide" for="timeline-overview-description-input">
                                    <span>Description</span>
                                    <textarea id="timeline-overview-description-input" name="description" rows="3">${this.escapeHTML(overview.description || "")}</textarea>
                                </label>

                                <label class="form-field" for="timeline-overview-calendar-input">
                                    <span>Calendar Name</span>
                                    <input id="timeline-overview-calendar-input" name="calendarName" type="text" autocomplete="off" value="${this.escapeHTML(overview.calendarName || "")}" />
                                </label>

                                <label class="form-field" for="timeline-overview-start-input">
                                    <span>Start Label</span>
                                    <input id="timeline-overview-start-input" name="startLabel" type="text" autocomplete="off" value="${this.escapeHTML(overview.startLabel || "")}" />
                                </label>

                                <label class="form-field" for="timeline-overview-end-input">
                                    <span>End Label</span>
                                    <input id="timeline-overview-end-input" name="endLabel" type="text" autocomplete="off" value="${this.escapeHTML(overview.endLabel || "")}" />
                                </label>

                                <label class="form-field form-field-wide" for="timeline-overview-notes-input">
                                    <span>Notes</span>
                                    <textarea id="timeline-overview-notes-input" name="notes" rows="4">${this.escapeHTML(overview.notes || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-timeline-modal">Cancel</button>
                                <button type="submit" class="button button-primary">Save Overview</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-timeline-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#timeline-overview-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleOverviewSubmit(projectId, event.currentTarget);
            });

            this.modalContainer.querySelector("#timeline-overview-title-input")?.focus();

        },


        handleOverviewSubmit(projectId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Timeline title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const now = new Date().toISOString();

            const saved = this.updateProjectTimeline(
                projectId,
                timeline => {

                    const nextOverview = this.normalizeOverview(
                        {
                            ...timeline.overview,
                            title,
                            description: String(formData.get("description") || ""),
                            calendarName: String(formData.get("calendarName") || ""),
                            startLabel: String(formData.get("startLabel") || ""),
                            endLabel: String(formData.get("endLabel") || ""),
                            notes: String(formData.get("notes") || ""),
                            updatedAt: now
                        },
                        projectId,
                        title
                    );

                    if (!nextOverview) {
                        return null;
                    }

                    return {
                        ...timeline,
                        overview: nextOverview
                    };

                },
                "timeline-overview-update"
            );

            if (!saved) {
                this.core.notify("Failed to save timeline overview.", "error");
                return;
            }

            this.selectedEntity = {
                type: "Overview",
                id: "overview"
            };

            this.closeModal();
            this.core.notify("Timeline overview updated.", "success");
            this.render(this.container);

        },


        showEraModal(projectId, eraId = null) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const timeline = this.getTimeline(project);
            const existing = eraId
                ? timeline.eras.find(item => item.id === eraId) || null
                : null;

            if (eraId && !existing) {
                this.core.notify("Era could not be found.", "error");
                return;
            }

            const heading = existing ? "Edit Era" : "New Era";

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="timeline-era-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">TIMELINE STUDIO</p>
                                <h2 id="timeline-era-title">${this.escapeHTML(heading)}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-timeline-modal" aria-label="Close era form">×</button>
                        </header>

                        <form id="timeline-era-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field form-field-wide" for="timeline-era-title-input">
                                    <span>Title *</span>
                                    <input id="timeline-era-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(existing?.title || "")}" />
                                </label>

                                <label class="form-field" for="timeline-era-start-input">
                                    <span>Start</span>
                                    <input id="timeline-era-start-input" name="start" type="text" autocomplete="off" value="${this.escapeHTML(existing?.start || "")}" />
                                </label>

                                <label class="form-field" for="timeline-era-end-input">
                                    <span>End</span>
                                    <input id="timeline-era-end-input" name="end" type="text" autocomplete="off" value="${this.escapeHTML(existing?.end || "")}" />
                                </label>

                                <label class="form-field" for="timeline-era-status-input">
                                    <span>Status</span>
                                    <select id="timeline-era-status-input" name="status">
                                        ${this.eraStatuses.map(status => `<option value="${this.escapeHTML(status)}" ${String(existing?.status || "Planned") === status ? "selected" : ""}>${this.escapeHTML(status)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-era-description-input">
                                    <span>Description</span>
                                    <textarea id="timeline-era-description-input" name="description" rows="3">${this.escapeHTML(existing?.description || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-era-notes-input">
                                    <span>Notes</span>
                                    <textarea id="timeline-era-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                                </label>
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-timeline-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${existing ? "Save Changes" : "Save Era"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-timeline-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#timeline-era-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleEraSubmit(projectId, eraId, event.currentTarget);
            });

            this.modalContainer.querySelector("#timeline-era-title-input")?.focus();

        },


        handleEraSubmit(projectId, eraId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Era title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const payload = {
                title,
                start: String(formData.get("start") || ""),
                end: String(formData.get("end") || ""),
                status: String(formData.get("status") || "Planned"),
                description: String(formData.get("description") || ""),
                notes: String(formData.get("notes") || ""),
                updatedAt: new Date().toISOString()
            };

            const saved = eraId
                ? this.updateEra(projectId, eraId, payload)
                : this.createEra(projectId, payload);

            if (!saved) {
                this.core.notify("Failed to save era.", "error");
                return;
            }

            this.closeModal();
            this.core.notify(`Era ${eraId ? "updated" : "created"}.`, "success");
            this.render(this.container);

        },


        showSequenceModal(projectId, sequenceId = null) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const timeline = this.getTimeline(project);
            const existing = sequenceId
                ? timeline.sequences.find(item => item.id === sequenceId) || null
                : null;

            if (sequenceId && !existing) {
                this.core.notify("Sequence could not be found.", "error");
                return;
            }

            const heading = existing ? "Edit Sequence" : "New Sequence";

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="timeline-sequence-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">TIMELINE STUDIO</p>
                                <h2 id="timeline-sequence-title">${this.escapeHTML(heading)}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-timeline-modal" aria-label="Close sequence form">×</button>
                        </header>

                        <form id="timeline-sequence-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field form-field-wide" for="timeline-sequence-title-input">
                                    <span>Title *</span>
                                    <input id="timeline-sequence-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(existing?.title || "")}" />
                                </label>

                                <label class="form-field" for="timeline-sequence-status-input">
                                    <span>Status</span>
                                    <select id="timeline-sequence-status-input" name="status">
                                        ${this.sequenceStatuses.map(status => `<option value="${this.escapeHTML(status)}" ${String(existing?.status || "Planned") === status ? "selected" : ""}>${this.escapeHTML(status)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-sequence-description-input">
                                    <span>Description</span>
                                    <textarea id="timeline-sequence-description-input" name="description" rows="3">${this.escapeHTML(existing?.description || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-sequence-notes-input">
                                    <span>Notes</span>
                                    <textarea id="timeline-sequence-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                                </label>
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-timeline-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${existing ? "Save Changes" : "Save Sequence"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-timeline-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#timeline-sequence-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleSequenceSubmit(projectId, sequenceId, event.currentTarget);
            });

            this.modalContainer.querySelector("#timeline-sequence-title-input")?.focus();

        },


        handleSequenceSubmit(projectId, sequenceId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Sequence title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const payload = {
                title,
                status: String(formData.get("status") || "Planned"),
                description: String(formData.get("description") || ""),
                notes: String(formData.get("notes") || ""),
                updatedAt: new Date().toISOString()
            };

            const saved = sequenceId
                ? this.updateSequence(projectId, sequenceId, payload)
                : this.createSequence(projectId, payload);

            if (!saved) {
                this.core.notify("Failed to save sequence.", "error");
                return;
            }

            this.closeModal();
            this.core.notify(`Sequence ${sequenceId ? "updated" : "created"}.`, "success");
            this.render(this.container);

        },


        showEventModal(projectId, eventId = null) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const timeline = this.getTimeline(project);
            const existing = eventId
                ? timeline.events.find(item => item.id === eventId) || null
                : null;

            if (eventId && !existing) {
                this.core.notify("Event could not be found.", "error");
                return;
            }

            const plot = this.getPlot(project);
            const chapters = this.getProjectChapters(project);
            const characters = this.getProjectCharacters(project);
            const locations = this.getProjectLocations(project);

            const heading = existing ? "Edit Event" : "New Event";

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="timeline-event-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">TIMELINE STUDIO</p>
                                <h2 id="timeline-event-title">${this.escapeHTML(heading)}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-timeline-modal" aria-label="Close event form">×</button>
                        </header>

                        <form id="timeline-event-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field form-field-wide" for="timeline-event-title-input">
                                    <span>Title *</span>
                                    <input id="timeline-event-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(existing?.title || "")}" />
                                </label>

                                <label class="form-field" for="timeline-event-date-precision-input">
                                    <span>Date Precision</span>
                                    <select id="timeline-event-date-precision-input" name="datePrecision">
                                        ${this.datePrecisions.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.datePrecision || "Unknown") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-date-value-input">
                                    <span>Date Value</span>
                                    <input id="timeline-event-date-value-input" name="dateValue" type="text" autocomplete="off" value="${this.escapeHTML(existing?.dateValue || "")}" />
                                </label>

                                <label class="form-field" for="timeline-event-end-date-input">
                                    <span>End Date</span>
                                    <input id="timeline-event-end-date-input" name="endDateValue" type="text" autocomplete="off" value="${this.escapeHTML(existing?.endDateValue || "")}" />
                                </label>

                                <label class="form-field form-field-wide" for="timeline-event-date-label-input">
                                    <span>Date Label</span>
                                    <input id="timeline-event-date-label-input" name="dateLabel" type="text" autocomplete="off" value="${this.escapeHTML(existing?.dateLabel || "")}" />
                                </label>

                                <label class="form-field" for="timeline-event-type-input">
                                    <span>Type</span>
                                    <input id="timeline-event-type-input" name="type" type="text" list="timeline-event-type-list" value="${this.escapeHTML(existing?.type || "Custom")}" />
                                    <datalist id="timeline-event-type-list">
                                        ${this.eventTypes.map(type => `<option value="${this.escapeHTML(type)}"></option>`).join("")}
                                    </datalist>
                                </label>

                                <label class="form-field" for="timeline-event-importance-input">
                                    <span>Importance</span>
                                    <select id="timeline-event-importance-input" name="importance">
                                        ${this.importanceLevels.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.importance || "Medium") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-status-input">
                                    <span>Status</span>
                                    <select id="timeline-event-status-input" name="status">
                                        ${this.eventStatuses.map(value => `<option value="${this.escapeHTML(value)}" ${String(existing?.status || "Planned") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-era-input">
                                    <span>Era</span>
                                    <select id="timeline-event-era-input" name="eraId">
                                        <option value="">Unassigned</option>
                                        ${timeline.eras.map(era => `<option value="${this.escapeHTML(era.id)}" ${existing?.eraId === era.id ? "selected" : ""}>${this.escapeHTML(era.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-sequence-input">
                                    <span>Sequence</span>
                                    <select id="timeline-event-sequence-input" name="sequenceId">
                                        <option value="">Unassigned</option>
                                        ${timeline.sequences.map(sequence => `<option value="${this.escapeHTML(sequence.id)}" ${existing?.sequenceId === sequence.id ? "selected" : ""}>${this.escapeHTML(sequence.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-relative-kind-input">
                                    <span>Relative Relationship</span>
                                    <select id="timeline-event-relative-kind-input" name="relativeKind">
                                        <option value="">None</option>
                                        <option value="Before" ${existing?.relativeKind === "Before" ? "selected" : ""}>Before</option>
                                        <option value="After" ${existing?.relativeKind === "After" ? "selected" : ""}>After</option>
                                        <option value="During" ${existing?.relativeKind === "During" ? "selected" : ""}>During</option>
                                        <option value="SamePeriod" ${existing?.relativeKind === "SamePeriod" ? "selected" : ""}>Same Period</option>
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-relative-type-input">
                                    <span>Relative Target Type</span>
                                    <select id="timeline-event-relative-type-input" name="relativeTargetType">
                                        <option value="">None</option>
                                        <option value="event" ${existing?.relativeTargetType === "event" ? "selected" : ""}>Event</option>
                                        <option value="era" ${existing?.relativeTargetType === "era" ? "selected" : ""}>Era</option>
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-relative-target-input">
                                    <span>Relative Target</span>
                                    <select id="timeline-event-relative-target-input" name="relativeTargetId"></select>
                                </label>

                                <label class="form-field" for="timeline-event-chapter-input">
                                    <span>Chapter Link</span>
                                    <select id="timeline-event-chapter-input" name="chapterId">
                                        <option value="">Unlinked</option>
                                        ${chapters.map(chapter => `<option value="${this.escapeHTML(chapter.id)}" ${existing?.chapterId === chapter.id ? "selected" : ""}>${this.escapeHTML(chapter.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-plot-arc-input">
                                    <span>Plot Arc</span>
                                    <select id="timeline-event-plot-arc-input" name="plotArcId">
                                        <option value="">Unlinked</option>
                                        ${plot.arcs.map(arc => `<option value="${this.escapeHTML(arc.id)}" ${existing?.plotArcId === arc.id ? "selected" : ""}>${this.escapeHTML(arc.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-plot-beat-input">
                                    <span>Plot Beat</span>
                                    <select id="timeline-event-plot-beat-input" name="plotBeatId">
                                        <option value="">Unlinked</option>
                                        ${plot.beats.map(beat => `<option value="${this.escapeHTML(beat.id)}" ${existing?.plotBeatId === beat.id ? "selected" : ""}>${this.escapeHTML(beat.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="timeline-event-plot-scene-input">
                                    <span>Plot Scene</span>
                                    <select id="timeline-event-plot-scene-input" name="plotSceneId">
                                        <option value="">Unlinked</option>
                                        ${plot.scenes.map(scene => `<option value="${this.escapeHTML(scene.id)}" ${existing?.plotSceneId === scene.id ? "selected" : ""}>${this.escapeHTML(scene.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-event-characters-input">
                                    <span>Characters</span>
                                    <select id="timeline-event-characters-input" name="characterIds" multiple size="4">
                                        ${characters.map(character => `<option value="${this.escapeHTML(character.id)}" ${Array.isArray(existing?.characterIds) && existing.characterIds.includes(character.id) ? "selected" : ""}>${this.escapeHTML(this.getCharacterName(character))}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-event-locations-input">
                                    <span>Locations</span>
                                    <select id="timeline-event-locations-input" name="worldIds" multiple size="4">
                                        ${locations.map(location => `<option value="${this.escapeHTML(location.id)}" ${Array.isArray(existing?.worldIds) && existing.worldIds.includes(location.id) ? "selected" : ""}>${this.escapeHTML(location.title)}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-event-description-input">
                                    <span>Description</span>
                                    <textarea id="timeline-event-description-input" name="description" rows="3">${this.escapeHTML(existing?.description || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="timeline-event-notes-input">
                                    <span>Notes</span>
                                    <textarea id="timeline-event-notes-input" name="notes" rows="3">${this.escapeHTML(existing?.notes || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-timeline-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${existing ? "Save Changes" : "Save Event"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-timeline-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            const relativeTypeInput = this.modalContainer.querySelector("#timeline-event-relative-type-input");
            const relativeTargetInput = this.modalContainer.querySelector("#timeline-event-relative-target-input");
            const relativeTargetValue = String(existing?.relativeTargetId || "").trim();

            const renderRelativeTargets = () => {

                const targetType = String(relativeTypeInput?.value || "").trim();

                if (targetType === "event") {

                    relativeTargetInput.innerHTML = `
                        <option value="">Select event</option>
                        ${timeline.events
                            .filter(event => event.id !== eventId)
                            .map(event => `<option value="${this.escapeHTML(event.id)}" ${relativeTargetValue === event.id ? "selected" : ""}>${this.escapeHTML(event.title)}</option>`)
                            .join("")}
                    `;

                    return;

                }

                if (targetType === "era") {

                    relativeTargetInput.innerHTML = `
                        <option value="">Select era</option>
                        ${timeline.eras
                            .map(era => `<option value="${this.escapeHTML(era.id)}" ${relativeTargetValue === era.id ? "selected" : ""}>${this.escapeHTML(era.title)}</option>`)
                            .join("")}
                    `;

                    return;

                }

                relativeTargetInput.innerHTML = "<option value=\"\">None</option>";

            };

            renderRelativeTargets();

            relativeTypeInput?.addEventListener("change", () => {
                renderRelativeTargets();
            });

            this.modalContainer.querySelector("#timeline-event-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleEventSubmit(projectId, eventId, event.currentTarget);
            });

            this.modalContainer.querySelector("#timeline-event-title-input")?.focus();

        },


        handleEventSubmit(projectId, eventId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Event title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const selectedMulti = name => Array.from(form.querySelectorAll(`[name="${name}"] option:checked`))
                .map(option => String(option.value || "").trim())
                .filter(Boolean);

            const payload = {
                title,
                description: String(formData.get("description") || ""),
                datePrecision: String(formData.get("datePrecision") || "Unknown"),
                dateLabel: String(formData.get("dateLabel") || ""),
                dateValue: String(formData.get("dateValue") || ""),
                endDateValue: String(formData.get("endDateValue") || ""),
                eraId: String(formData.get("eraId") || "").trim(),
                sequenceId: String(formData.get("sequenceId") || "").trim(),
                type: String(formData.get("type") || "Custom").trim() || "Custom",
                status: String(formData.get("status") || "Planned").trim() || "Planned",
                importance: String(formData.get("importance") || "Medium").trim() || "Medium",
                relativeKind: String(formData.get("relativeKind") || "").trim(),
                relativeTargetType: String(formData.get("relativeTargetType") || "").trim(),
                relativeTargetId: String(formData.get("relativeTargetId") || "").trim(),
                chapterId: String(formData.get("chapterId") || "").trim(),
                plotArcId: String(formData.get("plotArcId") || "").trim(),
                plotBeatId: String(formData.get("plotBeatId") || "").trim(),
                plotSceneId: String(formData.get("plotSceneId") || "").trim(),
                characterIds: selectedMulti("characterIds"),
                worldIds: selectedMulti("worldIds"),
                notes: String(formData.get("notes") || ""),
                updatedAt: new Date().toISOString()
            };

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const timeline = this.getTimeline(project);
            const plot = this.getPlot(project);

            if (!this.validateEventReferences(project, timeline, plot, payload, eventId)) {
                this.core.notify("One or more references are invalid or cross-project.", "error");
                return;
            }

            const saved = eventId
                ? this.updateEvent(projectId, eventId, payload)
                : this.createEvent(projectId, payload);

            if (!saved) {
                this.core.notify("Failed to save event.", "error");
                return;
            }

            this.closeModal();
            this.core.notify(`Event ${eventId ? "updated" : "created"}.`, "success");
            this.render(this.container);

        },


        createEra(projectId, payload) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const current = Array.isArray(timeline.eras)
                        ? [...timeline.eras]
                        : [];

                    const now = new Date().toISOString();
                    const candidate = {
                        ...payload,
                        id: AuthorOSHelpers.generateId("era"),
                        projectId,
                        order: current.length + 1,
                        createdAt: now,
                        updatedAt: now,
                        archivedAt: null
                    };

                    const normalized = this.normalizeEra(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    const next = {
                        ...timeline,
                        eras: [...current, normalized]
                    };

                    return this.normalizeTimeline(next, projectId);

                },
                "timeline-era-create",
                nextTimeline => {

                    const latest = nextTimeline.eras[nextTimeline.eras.length - 1];

                    if (latest) {
                        this.selectedEntity = {
                            type: "Era",
                            id: latest.id
                        };
                    }

                }
            );

        },


        updateEra(projectId, eraId, updates) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const eras = Array.isArray(timeline.eras)
                        ? [...timeline.eras]
                        : [];

                    const index = eras.findIndex(era => era.id === eraId);

                    if (index === -1) {
                        return null;
                    }

                    const existing = eras[index];

                    const normalized = this.normalizeEra(
                        {
                            ...existing,
                            ...updates,
                            id: existing.id,
                            projectId,
                            order: existing.order,
                            createdAt: existing.createdAt
                        },
                        projectId
                    );

                    if (!normalized) {
                        return null;
                    }

                    eras[index] = normalized;

                    return this.normalizeTimeline(
                        {
                            ...timeline,
                            eras
                        },
                        projectId
                    );

                },
                "timeline-era-update",
                () => {
                    this.selectedEntity = {
                        type: "Era",
                        id: eraId
                    };
                }
            );

        },


        createSequence(projectId, payload) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const current = Array.isArray(timeline.sequences)
                        ? [...timeline.sequences]
                        : [];

                    const now = new Date().toISOString();
                    const candidate = {
                        ...payload,
                        id: AuthorOSHelpers.generateId("sequence"),
                        projectId,
                        order: current.length + 1,
                        createdAt: now,
                        updatedAt: now,
                        archivedAt: null
                    };

                    const normalized = this.normalizeSequence(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    const next = {
                        ...timeline,
                        sequences: [...current, normalized]
                    };

                    return this.normalizeTimeline(next, projectId);

                },
                "timeline-sequence-create",
                nextTimeline => {

                    const latest = nextTimeline.sequences[nextTimeline.sequences.length - 1];

                    if (latest) {
                        this.selectedEntity = {
                            type: "Sequence",
                            id: latest.id
                        };
                    }

                }
            );

        },


        updateSequence(projectId, sequenceId, updates) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const sequences = Array.isArray(timeline.sequences)
                        ? [...timeline.sequences]
                        : [];

                    const index = sequences.findIndex(sequence => sequence.id === sequenceId);

                    if (index === -1) {
                        return null;
                    }

                    const existing = sequences[index];

                    const normalized = this.normalizeSequence(
                        {
                            ...existing,
                            ...updates,
                            id: existing.id,
                            projectId,
                            order: existing.order,
                            createdAt: existing.createdAt
                        },
                        projectId
                    );

                    if (!normalized) {
                        return null;
                    }

                    sequences[index] = normalized;

                    return this.normalizeTimeline(
                        {
                            ...timeline,
                            sequences
                        },
                        projectId
                    );

                },
                "timeline-sequence-update",
                () => {
                    this.selectedEntity = {
                        type: "Sequence",
                        id: sequenceId
                    };
                }
            );

        },


        createEvent(projectId, payload) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const current = Array.isArray(timeline.events)
                        ? [...timeline.events]
                        : [];

                    const now = new Date().toISOString();
                    const candidate = {
                        ...payload,
                        id: AuthorOSHelpers.generateId("timeline_event"),
                        projectId,
                        order: current.length + 1,
                        createdAt: now,
                        updatedAt: now,
                        archivedAt: null
                    };

                    const normalized = this.normalizeEvent(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    const next = {
                        ...timeline,
                        events: [...current, normalized]
                    };

                    return this.normalizeTimeline(next, projectId);

                },
                "timeline-event-create",
                nextTimeline => {

                    const latest = nextTimeline.events[nextTimeline.events.length - 1];

                    if (latest) {
                        this.selectedEntity = {
                            type: "Event",
                            id: latest.id
                        };
                    }

                }
            );

        },


        updateEvent(projectId, eventId, updates) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const events = Array.isArray(timeline.events)
                        ? [...timeline.events]
                        : [];

                    const index = events.findIndex(event => event.id === eventId);

                    if (index === -1) {
                        return null;
                    }

                    const existing = events[index];

                    const normalized = this.normalizeEvent(
                        {
                            ...existing,
                            ...updates,
                            id: existing.id,
                            projectId,
                            order: existing.order,
                            createdAt: existing.createdAt
                        },
                        projectId
                    );

                    if (!normalized) {
                        return null;
                    }

                    events[index] = normalized;

                    return this.normalizeTimeline(
                        {
                            ...timeline,
                            events
                        },
                        projectId
                    );

                },
                "timeline-event-update",
                () => {
                    this.selectedEntity = {
                        type: "Event",
                        id: eventId
                    };
                }
            );

        },


        duplicateEvent(projectId, eventId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                return;
            }

            const timeline = this.getTimeline(project);
            const source = timeline.events.find(event => event.id === eventId);

            if (!source) {
                this.core.notify("Event could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();

            const copy = {
                ...source,
                id: AuthorOSHelpers.generateId("timeline_event"),
                title: `${source.title} - Copy`,
                createdAt: now,
                updatedAt: now,
                archivedAt: null,
                order: timeline.events.length + 1,
                status: source.status === "Archived" ? "Planned" : source.status
            };

            const saved = this.createEvent(projectId, copy);

            if (!saved) {
                this.core.notify("Failed to duplicate event.", "error");
                return;
            }

            this.core.notify("Event duplicated.", "success");
            this.render(this.container);

        },


        moveEvent(projectId, eventId, direction) {

            const saved = this.updateProjectTimeline(
                projectId,
                timeline => {

                    const events = Array.isArray(timeline.events)
                        ? [...timeline.events]
                        : [];

                    const index = events.findIndex(event => event.id === eventId);

                    if (index === -1) {
                        return null;
                    }

                    const target = index + direction;

                    if (target < 0 || target >= events.length) {
                        return null;
                    }

                    const swap = events[index];
                    events[index] = events[target];
                    events[target] = swap;

                    const now = new Date().toISOString();

                    const reordered = events.map((event, eventIndex) => ({
                        ...event,
                        order: eventIndex + 1,
                        updatedAt: now
                    }));

                    return this.normalizeTimeline(
                        {
                            ...timeline,
                            events: reordered
                        },
                        projectId
                    );

                },
                "timeline-event-reorder",
                () => {
                    this.selectedEntity = {
                        type: "Event",
                        id: eventId
                    };
                }
            );

            if (!saved) {
                return;
            }

            this.core.notify("Event reordered.", "success");
            this.render(this.container);

        },


        archiveEvent(projectId, eventId) {

            const now = new Date().toISOString();

            const saved = this.updateEvent(
                projectId,
                eventId,
                {
                    status: "Archived",
                    archivedAt: now,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify("Failed to archive event.", "error");
                return;
            }

            this.core.notify("Event archived.", "success");
            this.render(this.container);

        },


        restoreEvent(projectId, eventId) {

            const now = new Date().toISOString();

            const saved = this.updateEvent(
                projectId,
                eventId,
                {
                    status: "Planned",
                    archivedAt: null,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify("Failed to restore event.", "error");
                return;
            }

            this.core.notify("Event restored.", "success");
            this.render(this.container);

        },


        confirmDeleteEvent(projectId, eventId) {

            const project = this.getProjectById(projectId);
            const timeline = this.getTimeline(project);
            const event = timeline.events.find(item => item.id === eventId);

            if (!event) {
                this.core.notify("Event could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete Timeline Event",
                content: `
                    <p>Delete \"${this.escapeHTML(event.title)}\"?</p>
                    <p>This removes only the timeline event and keeps manuscript, plot, character, and world records unchanged.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {

                    if (!this.deleteEvent(projectId, eventId)) {
                        this.core.notify("Failed to delete event.", "error");
                        return;
                    }

                    this.core.notify("Event deleted.", "success");
                    this.render(this.container);

                }
            });

        },


        deleteEvent(projectId, eventId) {

            return this.updateProjectTimeline(
                projectId,
                timeline => {

                    const events = Array.isArray(timeline.events)
                        ? [...timeline.events]
                        : [];

                    const exists = events.some(event => event.id === eventId);

                    if (!exists) {
                        return null;
                    }

                    const filtered = events
                        .filter(event => event.id !== eventId)
                        .map((event, index) => ({
                            ...event,
                            order: index + 1,
                            relativeTargetId: event.relativeTargetType === "event" && event.relativeTargetId === eventId
                                ? ""
                                : event.relativeTargetId,
                            relativeTargetType: event.relativeTargetType === "event" && event.relativeTargetId === eventId
                                ? ""
                                : event.relativeTargetType,
                            relativeKind: event.relativeTargetType === "event" && event.relativeTargetId === eventId
                                ? ""
                                : event.relativeKind
                        }));

                    return this.normalizeTimeline(
                        {
                            ...timeline,
                            events: filtered
                        },
                        projectId
                    );

                },
                "timeline-event-delete",
                () => {

                    if (this.selectedEntity.type === "Event" && this.selectedEntity.id === eventId) {
                        this.selectedEntity = {
                            type: "Overview",
                            id: "overview"
                        };
                    }

                }
            );

        },


        normalizeTimeline(timeline, projectId) {

            const next = this.cloneData(timeline);

            if (!next || typeof next !== "object") {
                return null;
            }

            const overview = this.normalizeOverview(next.overview, projectId, next.overview?.title || "Timeline");

            if (!overview) {
                return null;
            }

            next.overview = overview;

            next.eras = (Array.isArray(next.eras) ? next.eras : [])
                .map(era => this.normalizeEra(era, projectId))
                .filter(Boolean)
                .sort((left, right) => Number(left.order || 0) - Number(right.order || 0))
                .map((era, index) => ({ ...era, order: index + 1 }));

            next.sequences = (Array.isArray(next.sequences) ? next.sequences : [])
                .map(sequence => this.normalizeSequence(sequence, projectId))
                .filter(Boolean)
                .sort((left, right) => Number(left.order || 0) - Number(right.order || 0))
                .map((sequence, index) => ({ ...sequence, order: index + 1 }));

            next.events = (Array.isArray(next.events) ? next.events : [])
                .map(event => this.normalizeEvent(event, projectId))
                .filter(Boolean)
                .sort((left, right) => Number(left.order || 0) - Number(right.order || 0))
                .map((event, index) => ({ ...event, order: index + 1 }));

            return next;

        },


        updateProjectTimeline(projectId, updater, source, onSuccess) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return false;
            }

            const hydrated = this.ensureProjectTimelineShape(project);
            const nextProject = this.cloneData(hydrated.project);

            if (!nextProject) {
                return false;
            }

            const timeline = this.getTimeline(nextProject);
            const nextTimeline = updater(timeline);

            if (!nextTimeline || typeof nextTimeline !== "object") {
                return false;
            }

            const now = new Date().toISOString();

            nextProject.story.timeline = nextTimeline;
            nextProject.statistics = {
                ...(nextProject.statistics || {}),
                timeline: Array.isArray(nextTimeline.events)
                    ? nextTimeline.events.length
                    : 0,
                timelineEras: Array.isArray(nextTimeline.eras)
                    ? nextTimeline.eras.length
                    : 0
            };
            nextProject.updatedAt = now;
            nextProject.lastModified = now;

            if (!this.persistProject(nextProject, source || "timeline-update")) {
                return false;
            }

            if (typeof onSuccess === "function") {
                onSuccess(nextTimeline);
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

                const saved = projectsModule.saveProjects(next, { source: source || "timeline" });

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


        validateEventReferences(project, timeline, plot, payload, eventId) {

            const eraValid = !payload.eraId || timeline.eras.some(era => era.id === payload.eraId);
            const sequenceValid = !payload.sequenceId || timeline.sequences.some(sequence => sequence.id === payload.sequenceId);

            const chapterValid = !payload.chapterId || this.getProjectChapters(project).some(chapter => chapter.id === payload.chapterId);

            const plotArcValid = !payload.plotArcId || plot.arcs.some(arc => arc.id === payload.plotArcId);
            const plotBeatValid = !payload.plotBeatId || plot.beats.some(beat => beat.id === payload.plotBeatId);
            const plotSceneValid = !payload.plotSceneId || plot.scenes.some(scene => scene.id === payload.plotSceneId);

            const characterLookup = new Set(this.getProjectCharacters(project).map(character => character.id));
            const worldLookup = new Set(this.getProjectWorldEntries(project).map(entry => entry.id));

            const charactersValid = (payload.characterIds || []).every(id => characterLookup.has(id));
            const worldsValid = (payload.worldIds || []).every(id => worldLookup.has(id));

            const relativeKind = String(payload.relativeKind || "").trim();
            const relativeType = String(payload.relativeTargetType || "").trim();
            const relativeId = String(payload.relativeTargetId || "").trim();

            let relativeValid = true;

            if (relativeKind) {

                if (!relativeType || !relativeId) {
                    relativeValid = false;
                } else if (relativeType === "event") {
                    relativeValid = timeline.events.some(event => event.id === relativeId && event.id !== eventId);
                } else if (relativeType === "era") {
                    relativeValid = timeline.eras.some(era => era.id === relativeId);
                } else {
                    relativeValid = false;
                }

            }

            return Boolean(
                eraValid &&
                sequenceValid &&
                chapterValid &&
                plotArcValid &&
                plotBeatValid &&
                plotSceneValid &&
                charactersValid &&
                worldsValid &&
                relativeValid
            );

        },


        validateChronology(project, timeline) {

            const warnings = [];
            const events = Array.isArray(timeline.events) ? timeline.events : [];
            const eras = Array.isArray(timeline.eras) ? timeline.eras : [];

            eras.forEach(era => {

                const start = this.parseDateNumber(era.start);
                const end = this.parseDateNumber(era.end);

                if (start !== null && end !== null && end < start) {
                    warnings.push({
                        code: "INVALID_ERA_RANGE",
                        message: "Era end is earlier than era start.",
                        entities: [era.title]
                    });
                }

            });

            events.forEach(event => {

                if (event.datePrecision === "Range") {

                    const start = this.parseDateNumber(event.dateValue);
                    const end = this.parseDateNumber(event.endDateValue);

                    if (!String(event.dateValue || "").trim() || !String(event.endDateValue || "").trim()) {
                        warnings.push({
                            code: "INCOMPLETE_EVENT_RANGE",
                            message: "Range precision requires both start and end values.",
                            entities: [event.title]
                        });
                    } else if (start !== null && end !== null && end < start) {
                        warnings.push({
                            code: "INVALID_EVENT_RANGE",
                            message: "Event end date is earlier than start date.",
                            entities: [event.title]
                        });
                    }

                }

                if ((event.relativeKind || "") && (!event.relativeTargetType || !event.relativeTargetId)) {
                    warnings.push({
                        code: "INVALID_RELATIVE_REFERENCE",
                        message: "Relative relationship is missing a target.",
                        entities: [event.title]
                    });
                }

            });

            const adjacency = new Map();

            events.forEach(event => {
                adjacency.set(event.id, []);
            });

            events.forEach(event => {

                if (event.relativeTargetType !== "event" || !event.relativeTargetId) {
                    return;
                }

                if (event.relativeKind === "Before") {
                    adjacency.get(event.id)?.push(event.relativeTargetId);
                }

                if (event.relativeKind === "After") {
                    adjacency.get(event.relativeTargetId)?.push(event.id);
                }

            });

            const seen = new Set();
            const stack = new Set();

            const hasCycle = nodeId => {

                if (stack.has(nodeId)) {
                    return true;
                }

                if (seen.has(nodeId)) {
                    return false;
                }

                seen.add(nodeId);
                stack.add(nodeId);

                const targets = adjacency.get(nodeId) || [];

                for (let index = 0; index < targets.length; index += 1) {
                    if (hasCycle(targets[index])) {
                        return true;
                    }
                }

                stack.delete(nodeId);
                return false;

            };

            const cycleDetected = events.some(event => hasCycle(event.id));

            if (cycleDetected) {
                warnings.push({
                    code: "CONTRADICTORY_RELATIVE_ORDER",
                    message: "Relative before/after relationships contain a contradiction cycle.",
                    entities: events.map(event => event.title).slice(0, 3)
                });
            }

            return warnings;

        },


        describeEraRange(era) {

            const start = String(era.start || "").trim();
            const end = String(era.end || "").trim();

            if (start && end) {
                return `${start} - ${end}`;
            }

            if (start && !end) {
                return `${start} onward`;
            }

            if (!start && end) {
                return `Until ${end}`;
            }

            return "Open-ended";

        },


        getRelativeRelationshipLabel(timeline, event) {

            const kind = String(event.relativeKind || "").trim();
            const type = String(event.relativeTargetType || "").trim();
            const targetId = String(event.relativeTargetId || "").trim();

            if (!kind || !type || !targetId) {
                return "None";
            }

            if (type === "event") {

                const target = timeline.events.find(item => item.id === targetId);

                return target
                    ? `${kind} ${target.title}`
                    : `Missing event reference`;

            }

            if (type === "era") {

                const target = timeline.eras.find(item => item.id === targetId);

                return target
                    ? `${kind} ${target.title}`
                    : `Missing era reference`;

            }

            return "None";

        },


        openLinkedChapter(projectId, chapterId) {

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

            this.persistProject(nextProject, "timeline-open-chapter");
            this.core.navigation.navigate("manuscript");

        },


        getEventTypes(events) {

            const values = new Set(this.eventTypes);

            (Array.isArray(events) ? events : []).forEach(event => {
                const type = String(event?.type || "").trim();

                if (type) {
                    values.add(type);
                }
            });

            return Array.from(values);

        },


        getPlot(project) {

            if (!project?.story?.plot || typeof project.story.plot !== "object") {
                return {
                    arcs: [],
                    acts: [],
                    beats: [],
                    threads: [],
                    scenes: []
                };
            }

            return {
                arcs: Array.isArray(project.story.plot.arcs) ? project.story.plot.arcs : [],
                acts: Array.isArray(project.story.plot.acts) ? project.story.plot.acts : [],
                beats: Array.isArray(project.story.plot.beats) ? project.story.plot.beats : [],
                threads: Array.isArray(project.story.plot.threads) ? project.story.plot.threads : [],
                scenes: Array.isArray(project.story.plot.scenes) ? project.story.plot.scenes : []
            };

        },


        getProjectCharacters(project) {

            return Array.isArray(project?.story?.characters)
                ? project.story.characters.filter(character => character && character.id)
                : [];

        },


        getCharacterName(character) {
            return String(character?.displayName || character?.name || "Unnamed Character").trim() || "Unnamed Character";
        },


        resolveCharacterLabels(project, ids) {

            const lookup = new Map(this.getProjectCharacters(project).map(character => [character.id, character]));

            return (Array.isArray(ids) ? ids : []).map(id => {
                const target = lookup.get(id);
                return target ? this.getCharacterName(target) : "Missing character reference";
            });

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


        resolveWorldLabels(project, ids) {

            const lookup = new Map(this.getProjectWorldEntries(project).map(entry => [entry.id, entry]));

            return (Array.isArray(ids) ? ids : []).map(id => {
                const target = lookup.get(id);
                return target ? String(target.title || "Untitled World Entry") : "Missing world reference";
            });

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


        formatDate(value) {

            if (!value) {
                return "Unavailable";
            }

            const date = new Date(value);

            if (Number.isNaN(date.getTime())) {
                return "Unavailable";
            }

            return date.toLocaleString();

        },


        getTimelineSummaryCounts(projectId = null) {

            const project = projectId
                ? this.getProjectById(projectId)
                : this.getActiveProject();

            if (!project) {
                return {
                    events: 0,
                    planned: 0,
                    completed: 0,
                    eras: 0,
                    warnings: 0
                };
            }

            const timeline = this.getTimeline(project);
            const warnings = this.validateChronology(project, timeline);

            return {
                events: timeline.events.length,
                planned: timeline.events.filter(event => event.status === "Planned").length,
                completed: timeline.events.filter(event => event.status === "Completed").length,
                eras: timeline.eras.length,
                warnings: warnings.length
            };

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
                console.error("Timeline clone failed:", error);
                return null;
            }

        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();