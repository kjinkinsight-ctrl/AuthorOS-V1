/*
=========================================================
AUTHOROS
NOTES & RESEARCH STUDIO MODULE
Milestone 10
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSNotes = {

        name: "notes",

        core: null,

        container: null,

        modalContainer: null,

        activeProjectId: null,

        selectedEntity: {
            kind: "overview",
            id: "overview"
        },

        uiState: {
            search: "",
            kind: "All",
            category: "All",
            status: "All",
            priority: "All",
            tag: "All",
            sourceType: "All",
            linkedEntity: "All",
            visibility: "Active",
            sort: "updated-desc"
        },

        recordTypes: [
            "Note",
            "Research"
        ],

        categories: [
            "General",
            "Worldbuilding",
            "Character",
            "Plot",
            "Timeline",
            "Historical",
            "Location",
            "Culture",
            "Research",
            "Inspiration",
            "Reference",
            "Other"
        ],

        statuses: [
            "Draft",
            "Active",
            "Reviewed",
            "Archived"
        ],

        priorities: [
            "Low",
            "Medium",
            "High"
        ],

        sourceTypes: [
            "Book",
            "Article",
            "Website",
            "Paper",
            "Interview",
            "Video",
            "Image",
            "Document",
            "Other"
        ],

        initialize(core) {

            this.core = core;
            this.modalContainer = document.getElementById("modal-container");

            this.core.events.on("navigation:changed", nav => {

                if (nav?.route !== "notes") {
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

            const hydrated = this.ensureProjectNotesShape(project);

            if (hydrated.changed) {
                this.persistProject(hydrated.project, "notes-hydrate");
            }

            const currentProject = this.getProjectById(project.id) || hydrated.project;
            const notesStudio = this.getNotesStudio(currentProject);

            this.activeProjectId = currentProject.id;

            const entries = this.getCombinedEntries(currentProject, notesStudio);
            const filtered = this.getFilteredEntries(currentProject, notesStudio, entries);

            if (!this.isSelectedEntityPresent(entries)) {
                this.selectedEntity = {
                    kind: "overview",
                    id: notesStudio.overview.id
                };
            }

            const selected = this.getSelectedEntity(currentProject, notesStudio, entries);

            container.innerHTML = `
                <section class="notes-view library-view">

                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">NOTES & RESEARCH STUDIO</p>
                            <h1>Notes & Research</h1>
                            <p class="library-description">
                                Capture evidence, references, and working knowledge without altering manuscript text.
                            </p>
                            <p class="notes-project-context">
                                Project: ${this.escapeHTML(this.getProjectTitle(currentProject))}
                            </p>
                        </div>

                        <div class="library-actions notes-actions">
                            <button type="button" class="button button-primary" data-action="new-note-record">+ New Note</button>
                            <button type="button" class="button button-secondary" data-action="new-research-record">+ New Research</button>
                            <button type="button" class="button button-secondary" data-action="new-source-record">+ New Source</button>
                            <button type="button" class="button button-secondary" data-action="export-notes-json">Export JSON</button>
                            <button type="button" class="button button-secondary" data-action="import-notes-json">Import JSON</button>
                            <input id="notes-import-input" type="file" accept="application/json" class="visually-hidden" />
                        </div>
                    </header>

                    ${this.renderControls(currentProject, notesStudio)}

                    <div class="library-results-bar">
                        <span class="library-count">
                            ${filtered.length}
                            ${filtered.length === 1 ? "Record" : "Records"}
                        </span>
                        ${
                            this.hasActiveFilters()
                                ? `
                                    <span class="library-filter-state">
                                        Filtered from ${entries.length} ${entries.length === 1 ? "record" : "records"}
                                    </span>
                                `
                                : ""
                        }
                    </div>

                    ${this.renderSummaryCards(notesStudio)}

                    <div class="notes-layout ${selected ? "with-detail" : ""}">
                        <div class="notes-library-column">
                            ${
                                filtered.length
                                    ? this.renderEntryGrid(currentProject, notesStudio, filtered)
                                    : this.renderEmptyState(entries.length > 0)
                            }
                        </div>

                        <aside class="notes-detail-column" aria-label="Notes detail panel">
                            ${selected ? this.renderDetail(currentProject, notesStudio, selected) : this.renderDetailEmptyState()}
                        </aside>
                    </div>

                </section>
            `;

            this.bindEvents(container, currentProject.id, notesStudio);

        },


        renderMissingProjectState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">✎</div>
                    <p class="eyebrow">NOTES & RESEARCH STUDIO</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to manage notes and research.</p>
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


        ensureProjectNotesShape(project) {

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

            if (!next.story.notesStudio || typeof next.story.notesStudio !== "object") {
                next.story.notesStudio = {
                    overview: {
                        id: AuthorOSHelpers.generateId("notes_overview"),
                        projectId: next.id,
                        title: `${this.getProjectTitle(next)} Notes & Research`,
                        description: "",
                        createdAt: now,
                        updatedAt: now
                    },
                    records: [],
                    sources: []
                };
                changed = true;
            }

            const normalized = this.normalizeNotesStudio(next.story.notesStudio, next.id, this.getProjectTitle(next));

            if (!normalized) {
                return { project, changed: false };
            }

            if (JSON.stringify(next.story.notesStudio) !== JSON.stringify(normalized)) {
                next.story.notesStudio = normalized;
                changed = true;
            }

            if (!next.statistics || typeof next.statistics !== "object") {
                next.statistics = {};
                changed = true;
            }

            const records = next.story.notesStudio.records;
            const sources = next.story.notesStudio.sources;

            const notesCount = records.filter(record => record.type === "Note").length;
            const researchCount = records.filter(record => record.type === "Research").length;

            if (Number(next.statistics.notesCount || 0) !== notesCount) {
                next.statistics.notesCount = notesCount;
                changed = true;
            }

            if (Number(next.statistics.researchCount || 0) !== researchCount) {
                next.statistics.researchCount = researchCount;
                changed = true;
            }

            if (Number(next.statistics.sourcesCount || 0) !== sources.length) {
                next.statistics.sourcesCount = sources.length;
                changed = true;
            }

            return {
                project: next,
                changed
            };

        },


        normalizeNotesStudio(candidate, projectId, projectTitle) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const now = new Date().toISOString();

            const overviewCandidate = candidate.overview && typeof candidate.overview === "object"
                ? candidate.overview
                : {
                    id: AuthorOSHelpers.generateId("notes_overview"),
                    projectId,
                    title: `${projectTitle} Notes & Research`,
                    description: "",
                    createdAt: now,
                    updatedAt: now
                };

            const overview = this.normalizeOverview(overviewCandidate, projectId, projectTitle);

            if (!overview) {
                return null;
            }

            const records = Array.isArray(candidate.records)
                ? candidate.records
                    .map(record => this.normalizeRecord(record, projectId))
                    .filter(Boolean)
                    .sort((a, b) => this.safeTime(b.updatedAt) - this.safeTime(a.updatedAt))
                : [];

            const sources = Array.isArray(candidate.sources)
                ? candidate.sources
                    .map(source => this.normalizeSource(source, projectId))
                    .filter(Boolean)
                    .sort((a, b) => this.safeTime(b.updatedAt) - this.safeTime(a.updatedAt))
                : [];

            return {
                overview,
                records,
                sources
            };

        },


        normalizeOverview(candidate, projectId, projectTitle) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const now = new Date().toISOString();
            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("notes_overview"),
                projectId,
                title: String(candidate.title || `${projectTitle} Notes & Research`).trim() || `${projectTitle} Notes & Research`,
                description: String(candidate.description || ""),
                createdAt,
                updatedAt
            };

        },


        normalizeRecord(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const type = this.recordTypes.includes(String(candidate.type || "").trim())
                ? String(candidate.type).trim()
                : "Note";

            const status = this.statuses.includes(String(candidate.status || "").trim())
                ? String(candidate.status).trim()
                : "Draft";

            const priority = this.priorities.includes(String(candidate.priority || "").trim())
                ? String(candidate.priority).trim()
                : "Medium";

            const now = new Date().toISOString();
            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("note_record"),
                projectId,
                type,
                title: String(candidate.title || "").trim() || "Untitled Record",
                content: String(candidate.content || ""),
                summary: String(candidate.summary || ""),
                category: String(candidate.category || "General").trim() || "General",
                tags: this.normalizeTags(candidate.tags),
                status,
                priority,
                sourceIds: Array.isArray(candidate.sourceIds)
                    ? candidate.sourceIds.map(id => String(id || "").trim()).filter(Boolean)
                    : [],
                linkedEntityIds: Array.isArray(candidate.linkedEntityIds)
                    ? candidate.linkedEntityIds.map(id => String(id || "").trim()).filter(Boolean)
                    : [],
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeSource(candidate, projectId) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const normalizedProjectId = typeof candidate.projectId === "string" && candidate.projectId.trim()
                ? candidate.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            const sourceType = this.sourceTypes.includes(String(candidate.sourceType || "").trim())
                ? String(candidate.sourceType).trim()
                : "Other";

            const now = new Date().toISOString();
            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("source"),
                projectId,
                title: String(candidate.title || "").trim() || "Untitled Source",
                author: String(candidate.author || ""),
                publisher: String(candidate.publisher || ""),
                publicationDate: String(candidate.publicationDate || ""),
                url: String(candidate.url || ""),
                sourceType,
                citation: String(candidate.citation || ""),
                description: String(candidate.description || ""),
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };

        },


        normalizeTags(tags) {

            if (Array.isArray(tags)) {
                return tags
                    .map(tag => String(tag || "").trim())
                    .filter(Boolean);
            }

            if (typeof tags === "string") {
                return tags
                    .split(",")
                    .map(tag => String(tag || "").trim())
                    .filter(Boolean);
            }

            return [];

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


        safeTime(value) {

            const parsed = Date.parse(value || "");

            return Number.isNaN(parsed) ? 0 : parsed;

        },


        getNotesStudio(project) {

            if (!project?.story?.notesStudio || typeof project.story.notesStudio !== "object") {
                return {
                    overview: {
                        id: "overview",
                        projectId: project?.id || "",
                        title: `${this.getProjectTitle(project)} Notes & Research`,
                        description: "",
                        createdAt: new Date().toISOString(),
                        updatedAt: new Date().toISOString()
                    },
                    records: [],
                    sources: []
                };
            }

            return project.story.notesStudio;

        },


        getCombinedEntries(project, notesStudio) {

            const records = (Array.isArray(notesStudio.records) ? notesStudio.records : []).map(record => ({
                entryKind: "Record",
                id: record.id,
                title: record.title,
                updatedAt: record.updatedAt,
                createdAt: record.createdAt,
                data: record
            }));

            const sources = (Array.isArray(notesStudio.sources) ? notesStudio.sources : []).map(source => ({
                entryKind: "Source",
                id: source.id,
                title: source.title,
                updatedAt: source.updatedAt,
                createdAt: source.createdAt,
                data: source
            }));

            return [...records, ...sources];

        },


        renderControls(project, notesStudio) {

            const records = Array.isArray(notesStudio.records) ? notesStudio.records : [];
            const sources = Array.isArray(notesStudio.sources) ? notesStudio.sources : [];

            const uniqueTags = this.getUniqueTags(records);
            const linkedOptions = this.getEntityReferenceOptions(project, notesStudio);

            return `
                <div class="library-controls notes-controls">

                    <div class="library-search">
                        <label for="notes-search-input" class="visually-hidden">Search notes</label>
                        <span class="library-search-icon" aria-hidden="true">⌕</span>
                        <input
                            id="notes-search-input"
                            type="search"
                            class="library-search-input"
                            placeholder="Search notes and research..."
                            autocomplete="off"
                            value="${this.escapeHTML(this.uiState.search)}"
                        />
                        ${
                            this.uiState.search
                                ? `<button type="button" class="library-search-clear" data-action="clear-notes-search" aria-label="Clear search">×</button>`
                                : ""
                        }
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-kind-filter">Record Type</label>
                        <select id="notes-kind-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.kind === "All" ? "selected" : ""}>All</option>
                            <option value="Note" ${this.uiState.kind === "Note" ? "selected" : ""}>Note</option>
                            <option value="Research" ${this.uiState.kind === "Research" ? "selected" : ""}>Research</option>
                            <option value="Source" ${this.uiState.kind === "Source" ? "selected" : ""}>Source</option>
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-visibility-filter">Visibility</label>
                        <select id="notes-visibility-filter" class="library-filter-select">
                            <option value="Active" ${this.uiState.visibility === "Active" ? "selected" : ""}>Active only</option>
                            <option value="Archived" ${this.uiState.visibility === "Archived" ? "selected" : ""}>Archived only</option>
                            <option value="All" ${this.uiState.visibility === "All" ? "selected" : ""}>All</option>
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-category-filter">Category</label>
                        <select id="notes-category-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.category === "All" ? "selected" : ""}>All categories</option>
                            ${this.getCategoryOptions(records).map(category => `
                                <option value="${this.escapeHTML(category)}" ${this.uiState.category === category ? "selected" : ""}>${this.escapeHTML(category)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-status-filter">Status</label>
                        <select id="notes-status-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.status === "All" ? "selected" : ""}>All statuses</option>
                            ${this.statuses.map(status => `
                                <option value="${this.escapeHTML(status)}" ${this.uiState.status === status ? "selected" : ""}>${this.escapeHTML(status)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-priority-filter">Priority</label>
                        <select id="notes-priority-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.priority === "All" ? "selected" : ""}>All priorities</option>
                            ${this.priorities.map(priority => `
                                <option value="${this.escapeHTML(priority)}" ${this.uiState.priority === priority ? "selected" : ""}>${this.escapeHTML(priority)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-tag-filter">Tag</label>
                        <select id="notes-tag-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.tag === "All" ? "selected" : ""}>All tags</option>
                            ${uniqueTags.map(tag => `
                                <option value="${this.escapeHTML(tag)}" ${this.uiState.tag === tag ? "selected" : ""}>${this.escapeHTML(tag)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-source-type-filter">Source Type</label>
                        <select id="notes-source-type-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.sourceType === "All" ? "selected" : ""}>All source types</option>
                            ${this.getSourceTypeOptions(sources).map(sourceType => `
                                <option value="${this.escapeHTML(sourceType)}" ${this.uiState.sourceType === sourceType ? "selected" : ""}>${this.escapeHTML(sourceType)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-linked-filter">Linked Entity</label>
                        <select id="notes-linked-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.linkedEntity === "All" ? "selected" : ""}>All links</option>
                            ${linkedOptions.map(option => `
                                <option value="${this.escapeHTML(option.value)}" ${this.uiState.linkedEntity === option.value ? "selected" : ""}>${this.escapeHTML(option.label)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="notes-sort-filter">Sort</label>
                        <select id="notes-sort-filter" class="library-filter-select">
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently created</option>
                            <option value="title-asc" ${this.uiState.sort === "title-asc" ? "selected" : ""}>Title A-Z</option>
                            <option value="title-desc" ${this.uiState.sort === "title-desc" ? "selected" : ""}>Title Z-A</option>
                            <option value="priority-desc" ${this.uiState.sort === "priority-desc" ? "selected" : ""}>Priority</option>
                        </select>
                    </div>

                    ${
                        this.hasActiveFilters()
                            ? `<button type="button" class="library-clear-filters" data-action="clear-notes-filters">Clear filters</button>`
                            : ""
                    }

                </div>
            `;

        },


        renderSummaryCards(notesStudio) {

            const records = Array.isArray(notesStudio.records) ? notesStudio.records : [];
            const sources = Array.isArray(notesStudio.sources) ? notesStudio.sources : [];

            const notesCount = records.filter(record => record.type === "Note").length;
            const researchCount = records.filter(record => record.type === "Research").length;
            const archivedRecords = records.filter(record => String(record.status || "") === "Archived").length;
            const archivedSources = sources.filter(source => Boolean(source.archivedAt)).length;

            return `
                <section class="notes-summary-grid" aria-label="Notes and research summary">
                    <article class="notes-summary-card">
                        <h3>Notes</h3>
                        <p>${notesCount}</p>
                    </article>
                    <article class="notes-summary-card">
                        <h3>Research</h3>
                        <p>${researchCount}</p>
                    </article>
                    <article class="notes-summary-card">
                        <h3>Sources</h3>
                        <p>${sources.length}</p>
                    </article>
                    <article class="notes-summary-card">
                        <h3>Archived</h3>
                        <p>${archivedRecords + archivedSources}</p>
                    </article>
                </section>
            `;

        },


        hasActiveFilters() {

            return Boolean(
                this.uiState.search.trim() ||
                this.uiState.kind !== "All" ||
                this.uiState.category !== "All" ||
                this.uiState.status !== "All" ||
                this.uiState.priority !== "All" ||
                this.uiState.tag !== "All" ||
                this.uiState.sourceType !== "All" ||
                this.uiState.linkedEntity !== "All" ||
                this.uiState.visibility !== "Active" ||
                this.uiState.sort !== "updated-desc"
            );

        },


        clearFilters() {

            this.uiState = {
                search: "",
                kind: "All",
                category: "All",
                status: "All",
                priority: "All",
                tag: "All",
                sourceType: "All",
                linkedEntity: "All",
                visibility: "Active",
                sort: "updated-desc"
            };

            this.render(this.container);

        },


        getFilteredEntries(project, notesStudio, entries) {

            const sourceMap = new Map((notesStudio.sources || []).map(source => [source.id, source]));

            let filtered = [...entries];

            if (this.uiState.kind !== "All") {
                filtered = filtered.filter(entry => {

                    if (this.uiState.kind === "Source") {
                        return entry.entryKind === "Source";
                    }

                    return entry.entryKind === "Record" && entry.data.type === this.uiState.kind;

                });
            }

            if (this.uiState.visibility !== "All") {
                filtered = filtered.filter(entry => {

                    if (entry.entryKind === "Source") {
                        const archived = Boolean(entry.data.archivedAt);
                        return this.uiState.visibility === "Archived" ? archived : !archived;
                    }

                    const archived = String(entry.data.status || "") === "Archived" || Boolean(entry.data.archivedAt);
                    return this.uiState.visibility === "Archived" ? archived : !archived;

                });
            }

            if (this.uiState.category !== "All") {
                filtered = filtered.filter(entry => entry.entryKind === "Record" && String(entry.data.category || "") === this.uiState.category);
            }

            if (this.uiState.status !== "All") {
                filtered = filtered.filter(entry => entry.entryKind === "Record" && String(entry.data.status || "") === this.uiState.status);
            }

            if (this.uiState.priority !== "All") {
                filtered = filtered.filter(entry => entry.entryKind === "Record" && String(entry.data.priority || "") === this.uiState.priority);
            }

            if (this.uiState.tag !== "All") {
                filtered = filtered.filter(entry => entry.entryKind === "Record" && Array.isArray(entry.data.tags) && entry.data.tags.includes(this.uiState.tag));
            }

            if (this.uiState.sourceType !== "All") {
                filtered = filtered.filter(entry => {

                    if (entry.entryKind === "Source") {
                        return String(entry.data.sourceType || "") === this.uiState.sourceType;
                    }

                    return Array.isArray(entry.data.sourceIds) && entry.data.sourceIds.some(sourceId => {
                        const source = sourceMap.get(sourceId);
                        return source && String(source.sourceType || "") === this.uiState.sourceType;
                    });

                });
            }

            if (this.uiState.linkedEntity !== "All") {
                filtered = filtered.filter(entry => entry.entryKind === "Record" && Array.isArray(entry.data.linkedEntityIds) && entry.data.linkedEntityIds.includes(this.uiState.linkedEntity));
            }

            const search = this.uiState.search.trim().toLowerCase();

            if (search) {
                filtered = filtered.filter(entry => this.matchesSearch(project, notesStudio, sourceMap, entry, search));
            }

            return this.sortEntries(filtered);

        },


        matchesSearch(project, notesStudio, sourceMap, entry, search) {

            if (entry.entryKind === "Source") {
                const source = entry.data;

                const sourceSearch = [
                    source.title,
                    source.author,
                    source.publisher,
                    source.publicationDate,
                    source.url,
                    source.sourceType,
                    source.citation,
                    source.description,
                    source.notes
                ]
                    .filter(Boolean)
                    .join(" ")
                    .toLowerCase();

                return sourceSearch.includes(search);
            }

            const record = entry.data;
            const linkedSources = (Array.isArray(record.sourceIds) ? record.sourceIds : [])
                .map(id => sourceMap.get(id))
                .filter(Boolean)
                .map(source => `${source.title} ${source.author} ${source.citation}`)
                .join(" ");

            const linkedEntities = this.resolveEntityTokens(project, notesStudio, record.linkedEntityIds || [])
                .map(link => `${link.kindLabel} ${link.label}`)
                .join(" ");

            const content = [
                record.title,
                record.type,
                record.content,
                record.summary,
                record.category,
                (record.tags || []).join(" "),
                record.status,
                record.priority,
                linkedSources,
                linkedEntities,
                record.notes
            ]
                .filter(Boolean)
                .join(" ")
                .toLowerCase();

            return content.includes(search);

        },


        sortEntries(entries) {

            const list = [...entries];

            const priorityRank = {
                Low: 1,
                Medium: 2,
                High: 3
            };

            if (this.uiState.sort === "created-desc") {
                return list.sort((left, right) => this.safeTime(right.createdAt) - this.safeTime(left.createdAt));
            }

            if (this.uiState.sort === "title-asc") {
                return list.sort((left, right) => this.getEntryTitle(left).localeCompare(this.getEntryTitle(right), undefined, { sensitivity: "base" }));
            }

            if (this.uiState.sort === "title-desc") {
                return list.sort((left, right) => this.getEntryTitle(right).localeCompare(this.getEntryTitle(left), undefined, { sensitivity: "base" }));
            }

            if (this.uiState.sort === "priority-desc") {
                return list.sort((left, right) => {

                    const leftPriority = left.entryKind === "Record" ? String(left.data.priority || "Medium") : "Medium";
                    const rightPriority = right.entryKind === "Record" ? String(right.data.priority || "Medium") : "Medium";

                    const diff = (priorityRank[rightPriority] || 0) - (priorityRank[leftPriority] || 0);

                    if (diff !== 0) {
                        return diff;
                    }

                    return this.safeTime(right.updatedAt) - this.safeTime(left.updatedAt);

                });
            }

            return list.sort((left, right) => this.safeTime(right.updatedAt) - this.safeTime(left.updatedAt));

        },


        renderEntryGrid(project, notesStudio, entries) {

            return `
                <div class="project-grid notes-grid">
                    ${entries.map(entry => this.renderEntryCard(project, notesStudio, entry)).join("")}
                </div>
            `;

        },


        renderEntryCard(project, notesStudio, entry) {

            if (entry.entryKind === "Source") {
                return this.renderSourceCard(notesStudio, entry);
            }

            return this.renderRecordCard(project, notesStudio, entry);

        },


        renderRecordCard(project, notesStudio, entry) {

            const record = entry.data;
            const selected = this.selectedEntity.kind === "record" && this.selectedEntity.id === record.id;
            const preview = String(record.summary || record.content || "").trim() || "No content yet.";
            const sourceCount = Array.isArray(record.sourceIds) ? record.sourceIds.length : 0;
            const linkedCount = Array.isArray(record.linkedEntityIds) ? record.linkedEntityIds.length : 0;

            return `
                <article class="project-card notes-card ${selected ? "selected" : ""}">
                    <div class="project-card-body">
                        <header class="notes-card-header">
                            <h2>${this.escapeHTML(record.title)}</h2>
                            <p class="notes-card-updated">Updated ${this.escapeHTML(this.formatDate(record.updatedAt))}</p>
                        </header>

                        <dl class="notes-card-meta">
                            <div><dt>Type</dt><dd>${this.escapeHTML(record.type)}</dd></div>
                            <div><dt>Category</dt><dd>${this.escapeHTML(record.category || "General")}</dd></div>
                            <div><dt>Status</dt><dd>${this.escapeHTML(record.status)}</dd></div>
                            <div><dt>Priority</dt><dd>${this.escapeHTML(record.priority)}</dd></div>
                            <div><dt>Sources</dt><dd>${this.escapeHTML(String(sourceCount))}</dd></div>
                            <div><dt>Links</dt><dd>${this.escapeHTML(String(linkedCount))}</dd></div>
                        </dl>

                        <p class="notes-card-summary">${this.escapeHTML(this.truncate(preview, 220))}</p>

                        ${
                            Array.isArray(record.tags) && record.tags.length
                                ? `<p class="notes-card-tags">${record.tags.map(tag => `#${this.escapeHTML(tag)}`).join(" ")}</p>`
                                : ""
                        }

                        <div class="idea-card-actions">
                            <button type="button" class="button button-secondary" data-action="open-notes-record" data-record-id="${this.escapeHTML(record.id)}">Open</button>
                            <button type="button" class="button button-secondary" data-action="edit-notes-record" data-record-id="${this.escapeHTML(record.id)}">Edit</button>
                            <button type="button" class="button button-secondary" data-action="duplicate-notes-record" data-record-id="${this.escapeHTML(record.id)}">Duplicate</button>
                            ${
                                String(record.status || "") === "Archived"
                                    ? `<button type="button" class="button button-secondary" data-action="restore-notes-record" data-record-id="${this.escapeHTML(record.id)}">Restore</button>`
                                    : `<button type="button" class="button button-secondary" data-action="archive-notes-record" data-record-id="${this.escapeHTML(record.id)}">Archive</button>`
                            }
                            <button type="button" class="button button-danger" data-action="delete-notes-record" data-record-id="${this.escapeHTML(record.id)}">Delete</button>
                        </div>
                    </div>
                </article>
            `;

        },


        renderSourceCard(notesStudio, entry) {

            const source = entry.data;
            const selected = this.selectedEntity.kind === "source" && this.selectedEntity.id === source.id;
            const linkedCount = (Array.isArray(notesStudio.records) ? notesStudio.records : []).filter(record =>
                Array.isArray(record.sourceIds) && record.sourceIds.includes(source.id)
            ).length;

            return `
                <article class="project-card notes-card ${selected ? "selected" : ""}">
                    <div class="project-card-body">
                        <header class="notes-card-header">
                            <h2>${this.escapeHTML(source.title)}</h2>
                            <p class="notes-card-updated">Updated ${this.escapeHTML(this.formatDate(source.updatedAt))}</p>
                        </header>

                        <dl class="notes-card-meta">
                            <div><dt>Type</dt><dd>Source</dd></div>
                            <div><dt>Source Type</dt><dd>${this.escapeHTML(source.sourceType || "Other")}</dd></div>
                            <div><dt>Author</dt><dd>${this.escapeHTML(String(source.author || "").trim() || "Unknown")}</dd></div>
                            <div><dt>Linked Research</dt><dd>${this.escapeHTML(String(linkedCount))}</dd></div>
                            <div><dt>Publisher</dt><dd>${this.escapeHTML(String(source.publisher || "").trim() || "Unknown")}</dd></div>
                            <div><dt>Date</dt><dd>${this.escapeHTML(String(source.publicationDate || "").trim() || "Unknown")}</dd></div>
                        </dl>

                        <p class="notes-card-summary">${this.escapeHTML(this.truncate(source.description || source.notes || source.citation || "No source notes yet.", 220))}</p>

                        <div class="idea-card-actions">
                            <button type="button" class="button button-secondary" data-action="open-source-record" data-source-id="${this.escapeHTML(source.id)}">Open</button>
                            <button type="button" class="button button-secondary" data-action="edit-source-record" data-source-id="${this.escapeHTML(source.id)}">Edit</button>
                            <button type="button" class="button button-secondary" data-action="duplicate-source-record" data-source-id="${this.escapeHTML(source.id)}">Duplicate</button>
                            ${
                                source.archivedAt
                                    ? `<button type="button" class="button button-secondary" data-action="restore-source-record" data-source-id="${this.escapeHTML(source.id)}">Restore</button>`
                                    : `<button type="button" class="button button-secondary" data-action="archive-source-record" data-source-id="${this.escapeHTML(source.id)}">Archive</button>`
                            }
                            <button type="button" class="button button-danger" data-action="delete-source-record" data-source-id="${this.escapeHTML(source.id)}">Delete</button>
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
                        <h2>No records match your filters</h2>
                        <p>Adjust search, filters, or sorting.</p>
                        <button type="button" class="button button-secondary" data-action="clear-notes-filters">Clear filters</button>
                    </section>
                `;
            }

            return `
                <section class="library-empty-state">
                    <div class="empty-state-icon">✎</div>
                    <h2>No notes or sources yet</h2>
                    <p>Create a note, research record, or source to begin your knowledge base.</p>
                    <div class="notes-empty-actions">
                        <button type="button" class="button button-primary" data-action="new-note-record">Add Note</button>
                        <button type="button" class="button button-secondary" data-action="new-research-record">Add Research</button>
                        <button type="button" class="button button-secondary" data-action="new-source-record">Add Source</button>
                    </div>
                </section>
            `;

        },


        renderDetailEmptyState() {

            return `
                <section class="idea-detail-empty-state">
                    <h3>Select a record</h3>
                    <p>Open a note, research entry, or source to inspect details.</p>
                </section>
            `;

        },


        getSelectedEntity(project, notesStudio, entries) {

            if (this.selectedEntity.kind === "overview") {
                return {
                    kind: "overview",
                    id: notesStudio.overview.id
                };
            }

            if (this.selectedEntity.kind === "record") {
                const found = entries.find(entry => entry.entryKind === "Record" && entry.id === this.selectedEntity.id);
                return found ? this.selectedEntity : null;
            }

            if (this.selectedEntity.kind === "source") {
                const found = entries.find(entry => entry.entryKind === "Source" && entry.id === this.selectedEntity.id);
                return found ? this.selectedEntity : null;
            }

            return null;

        },


        isSelectedEntityPresent(entries) {

            if (this.selectedEntity.kind === "overview") {
                return true;
            }

            if (this.selectedEntity.kind === "record") {
                return entries.some(entry => entry.entryKind === "Record" && entry.id === this.selectedEntity.id);
            }

            if (this.selectedEntity.kind === "source") {
                return entries.some(entry => entry.entryKind === "Source" && entry.id === this.selectedEntity.id);
            }

            return false;

        },


        renderDetail(project, notesStudio, selected) {

            if (selected.kind === "overview") {
                return this.renderOverviewDetail(notesStudio.overview);
            }

            if (selected.kind === "record") {
                return this.renderRecordDetail(project, notesStudio, selected.id);
            }

            if (selected.kind === "source") {
                return this.renderSourceDetail(project, notesStudio, selected.id);
            }

            return this.renderDetailEmptyState();

        },


        renderOverviewDetail(overview) {

            return `
                <article class="idea-detail-card notes-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">NOTES OVERVIEW</p>
                        <h2>${this.escapeHTML(overview.title || "Notes & Research")}</h2>
                    </header>

                    ${this.renderDetailTextBlock("Description", overview.description)}

                    <dl class="idea-detail-meta">
                        <div><dt>Created</dt><dd>${this.escapeHTML(this.formatDate(overview.createdAt))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(overview.updatedAt))}</dd></div>
                    </dl>
                </article>
            `;

        },


        renderRecordDetail(project, notesStudio, recordId) {

            const record = (notesStudio.records || []).find(item => item.id === recordId);

            if (!record) {
                return this.renderDetailEmptyState();
            }

            const sourceMap = new Map((notesStudio.sources || []).map(source => [source.id, source]));
            const linkedSources = (Array.isArray(record.sourceIds) ? record.sourceIds : []).map(sourceId => {
                const source = sourceMap.get(sourceId);
                return {
                    id: sourceId,
                    label: source ? source.title : "Missing source reference",
                    missing: !source
                };
            });

            const linkedEntities = this.resolveEntityTokens(project, notesStudio, record.linkedEntityIds || []);

            return `
                <article class="idea-detail-card notes-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">${this.escapeHTML(record.type.toUpperCase())}</p>
                        <h2>${this.escapeHTML(record.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(record.category)} | ${this.escapeHTML(record.status)} | ${this.escapeHTML(record.priority)}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Created</dt><dd>${this.escapeHTML(this.formatDate(record.createdAt))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(record.updatedAt))}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("Summary", record.summary)}
                    ${this.renderDetailTextBlock("Content", record.content)}
                    ${this.renderDetailTextBlock("Tags", (record.tags || []).length ? record.tags.join(", ") : "No tags")}

                    <section class="idea-detail-section">
                        <h3>Linked Sources</h3>
                        ${
                            linkedSources.length
                                ? `
                                    <ul class="notes-reference-list">
                                        ${linkedSources.map(source => `
                                            <li>
                                                <div class="notes-reference-main">
                                                    <p>${this.escapeHTML(source.label)}</p>
                                                </div>
                                                <div class="notes-reference-actions">
                                                    ${source.missing ? "" : `<button type=\"button\" class=\"button button-secondary\" data-action=\"open-linked-source\" data-source-id=\"${this.escapeHTML(source.id)}\">Open Source</button>`}
                                                </div>
                                            </li>
                                        `).join("")}
                                    </ul>
                                `
                                : "<p>No linked sources.</p>"
                        }
                    </section>

                    <section class="idea-detail-section">
                        <h3>Linked Entities</h3>
                        ${
                            linkedEntities.length
                                ? `
                                    <ul class="notes-reference-list">
                                        ${linkedEntities.map(link => `
                                            <li>
                                                <div class="notes-reference-main">
                                                    <strong>${this.escapeHTML(link.kindLabel)}</strong>
                                                    <p>${this.escapeHTML(link.label)}</p>
                                                </div>
                                                <div class="notes-reference-actions">
                                                    ${link.missing ? "" : `<button type=\"button\" class=\"button button-secondary\" data-action=\"open-linked-entity\" data-token=\"${this.escapeHTML(link.token)}\">Open</button>`}
                                                </div>
                                            </li>
                                        `).join("")}
                                    </ul>
                                `
                                : "<p>No linked entities.</p>"
                        }
                    </section>

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-notes-record" data-record-id="${this.escapeHTML(record.id)}">Edit</button>
                    </div>
                </article>
            `;

        },


        renderSourceDetail(project, notesStudio, sourceId) {

            const source = (notesStudio.sources || []).find(item => item.id === sourceId);

            if (!source) {
                return this.renderDetailEmptyState();
            }

            const linkedRecords = (notesStudio.records || []).filter(record =>
                Array.isArray(record.sourceIds) && record.sourceIds.includes(source.id)
            );

            return `
                <article class="idea-detail-card notes-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">SOURCE</p>
                        <h2>${this.escapeHTML(source.title)}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(source.sourceType || "Other")}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Author</dt><dd>${this.escapeHTML(String(source.author || "").trim() || "Unknown")}</dd></div>
                        <div><dt>Publisher</dt><dd>${this.escapeHTML(String(source.publisher || "").trim() || "Unknown")}</dd></div>
                        <div><dt>Publication</dt><dd>${this.escapeHTML(String(source.publicationDate || "").trim() || "Unknown")}</dd></div>
                    </dl>

                    ${this.renderDetailTextBlock("URL", source.url)}
                    ${this.renderDetailTextBlock("Citation", source.citation)}
                    ${this.renderDetailTextBlock("Description", source.description)}
                    ${this.renderDetailTextBlock("Notes", source.notes)}

                    <section class="idea-detail-section">
                        <h3>Linked Notes & Research</h3>
                        ${
                            linkedRecords.length
                                ? `
                                    <ul class="notes-reference-list">
                                        ${linkedRecords.map(record => `
                                            <li>
                                                <div class="notes-reference-main">
                                                    <strong>${this.escapeHTML(record.type)}</strong>
                                                    <p>${this.escapeHTML(record.title)}</p>
                                                </div>
                                                <div class="notes-reference-actions">
                                                    <button type="button" class="button button-secondary" data-action="open-notes-record" data-record-id="${this.escapeHTML(record.id)}">Open</button>
                                                </div>
                                            </li>
                                        `).join("")}
                                    </ul>
                                `
                                : "<p>No linked records.</p>"
                        }
                    </section>

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-source-record" data-source-id="${this.escapeHTML(source.id)}">Edit</button>
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


        bindEvents(container, projectId, notesStudio) {

            container.querySelectorAll('[data-action="new-note-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showRecordModal(projectId, "Note");
                });
            });

            container.querySelectorAll('[data-action="new-research-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showRecordModal(projectId, "Research");
                });
            });

            container.querySelectorAll('[data-action="new-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showSourceModal(projectId);
                });
            });

            container.querySelector('[data-action="export-notes-json"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.exportNotesData(projectId);
            });

            container.querySelector('[data-action="import-notes-json"]')?.addEventListener("click", event => {
                event.preventDefault();
                const input = container.querySelector("#notes-import-input");
                input?.click();
            });

            container.querySelector("#notes-import-input")?.addEventListener("change", event => {
                const input = event.currentTarget;
                this.importNotesData(projectId, input?.files?.[0] || null);
                if (input) {
                    input.value = "";
                }
            });

            const searchInput = container.querySelector("#notes-search-input");

            searchInput?.addEventListener("input", () => {
                this.uiState.search = String(searchInput.value || "");
                this.render(this.container);
            });

            container.querySelector('[data-action="clear-notes-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.search = "";
                this.render(this.container);
            });

            [
                ["#notes-kind-filter", "kind", "All"],
                ["#notes-category-filter", "category", "All"],
                ["#notes-status-filter", "status", "All"],
                ["#notes-priority-filter", "priority", "All"],
                ["#notes-tag-filter", "tag", "All"],
                ["#notes-source-type-filter", "sourceType", "All"],
                ["#notes-linked-filter", "linkedEntity", "All"],
                ["#notes-visibility-filter", "visibility", "Active"],
                ["#notes-sort-filter", "sort", "updated-desc"]
            ].forEach(([selector, key, fallback]) => {

                const input = container.querySelector(selector);

                input?.addEventListener("change", () => {
                    this.uiState[key] = String(input.value || fallback);
                    this.render(this.container);
                });

            });

            container.querySelectorAll('[data-action="clear-notes-filters"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.clearFilters();
                });
            });

            container.querySelectorAll('[data-action="open-notes-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.selectedEntity = {
                        kind: "record",
                        id: button.dataset.recordId
                    };
                    this.render(this.container);
                });
            });

            container.querySelectorAll('[data-action="edit-notes-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showRecordModal(projectId, null, button.dataset.recordId);
                });
            });

            container.querySelectorAll('[data-action="duplicate-notes-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.duplicateRecord(projectId, button.dataset.recordId);
                });
            });

            container.querySelectorAll('[data-action="archive-notes-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.archiveRecord(projectId, button.dataset.recordId);
                });
            });

            container.querySelectorAll('[data-action="restore-notes-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.restoreRecord(projectId, button.dataset.recordId);
                });
            });

            container.querySelectorAll('[data-action="delete-notes-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.confirmDeleteRecord(projectId, button.dataset.recordId);
                });
            });

            container.querySelectorAll('[data-action="open-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.selectedEntity = {
                        kind: "source",
                        id: button.dataset.sourceId
                    };
                    this.render(this.container);
                });
            });

            container.querySelectorAll('[data-action="edit-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showSourceModal(projectId, button.dataset.sourceId);
                });
            });

            container.querySelectorAll('[data-action="duplicate-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.duplicateSource(projectId, button.dataset.sourceId);
                });
            });

            container.querySelectorAll('[data-action="archive-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.archiveSource(projectId, button.dataset.sourceId);
                });
            });

            container.querySelectorAll('[data-action="restore-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.restoreSource(projectId, button.dataset.sourceId);
                });
            });

            container.querySelectorAll('[data-action="delete-source-record"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.confirmDeleteSource(projectId, button.dataset.sourceId);
                });
            });

            container.querySelectorAll('[data-action="open-linked-source"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.selectedEntity = {
                        kind: "source",
                        id: button.dataset.sourceId
                    };
                    this.render(this.container);
                });
            });

            container.querySelectorAll('[data-action="open-linked-entity"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openLinkedEntity(projectId, button.dataset.token);
                });
            });

        },


        showRecordModal(projectId, forcedType = null, recordId = null) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const notesStudio = this.getNotesStudio(project);

            const existing = recordId
                ? (notesStudio.records || []).find(record => record.id === recordId) || null
                : null;

            if (recordId && !existing) {
                this.core.notify("Record could not be found.", "error");
                return;
            }

            const type = forcedType || existing?.type || "Note";

            const sourceOptions = Array.isArray(notesStudio.sources)
                ? notesStudio.sources
                : [];

            const linked = this.getEntityReferenceOptions(project, notesStudio);
            const existingLinks = new Set(existing?.linkedEntityIds || []);

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="notes-record-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">NOTES & RESEARCH</p>
                                <h2 id="notes-record-modal-title">${existing ? "Edit" : "New"} ${this.escapeHTML(type)}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-notes-modal" aria-label="Close notes form">×</button>
                        </header>

                        <form id="notes-record-form" class="project-form" novalidate>
                            <input type="hidden" name="type" value="${this.escapeHTML(type)}" />
                            <div class="project-form-grid">

                                <label class="form-field" for="notes-record-type-input">
                                    <span>Type *</span>
                                    <select id="notes-record-type-input" name="typeSelect">
                                        ${this.recordTypes.map(option => `
                                            <option value="${this.escapeHTML(option)}" ${type === option ? "selected" : ""}>${this.escapeHTML(option)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="notes-record-title-input">
                                    <span>Title *</span>
                                    <input id="notes-record-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(existing?.title || "")}" />
                                </label>

                                <label class="form-field" for="notes-record-category-input">
                                    <span>Category</span>
                                    <input id="notes-record-category-input" name="category" type="text" list="notes-category-list" value="${this.escapeHTML(existing?.category || "General")}" />
                                    <datalist id="notes-category-list">
                                        ${this.categories.map(category => `<option value="${this.escapeHTML(category)}"></option>`).join("")}
                                    </datalist>
                                </label>

                                <label class="form-field" for="notes-record-status-input">
                                    <span>Status</span>
                                    <select id="notes-record-status-input" name="status">
                                        ${this.statuses.map(status => `
                                            <option value="${this.escapeHTML(status)}" ${String(existing?.status || "Draft") === status ? "selected" : ""}>${this.escapeHTML(status)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="notes-record-priority-input">
                                    <span>Priority</span>
                                    <select id="notes-record-priority-input" name="priority">
                                        ${this.priorities.map(priority => `
                                            <option value="${this.escapeHTML(priority)}" ${String(existing?.priority || "Medium") === priority ? "selected" : ""}>${this.escapeHTML(priority)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="notes-record-tags-input">
                                    <span>Tags (comma-separated)</span>
                                    <input id="notes-record-tags-input" name="tags" type="text" autocomplete="off" value="${this.escapeHTML((existing?.tags || []).join(", "))}" />
                                </label>

                                <label class="form-field form-field-wide" for="notes-record-summary-input">
                                    <span>Summary</span>
                                    <textarea id="notes-record-summary-input" name="summary" rows="3">${this.escapeHTML(existing?.summary || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="notes-record-content-input">
                                    <span>Content</span>
                                    <textarea id="notes-record-content-input" name="content" rows="8">${this.escapeHTML(existing?.content || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="notes-record-sources-input">
                                    <span>Linked Sources</span>
                                    <select id="notes-record-sources-input" name="sourceIds" multiple size="5">
                                        ${sourceOptions.map(source => `
                                            <option value="${this.escapeHTML(source.id)}" ${Array.isArray(existing?.sourceIds) && existing.sourceIds.includes(source.id) ? "selected" : ""}>${this.escapeHTML(source.title)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="notes-record-linked-input">
                                    <span>Linked Entities</span>
                                    <select id="notes-record-linked-input" name="linkedEntityIds" multiple size="8">
                                        ${linked.map(option => `
                                            <option value="${this.escapeHTML(option.value)}" ${existingLinks.has(option.value) ? "selected" : ""}>${this.escapeHTML(option.label)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-notes-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${existing ? "Save Changes" : `Save ${this.escapeHTML(type)}`}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelector("#notes-record-type-input")?.addEventListener("change", event => {
                const form = this.modalContainer.querySelector("#notes-record-form");
                if (form) {
                    form.querySelector('[name="type"]')?.setAttribute("value", String(event.target.value || "Note"));
                }
            });

            this.modalContainer.querySelectorAll('[data-action="close-notes-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#notes-record-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleRecordSubmit(projectId, recordId, event.currentTarget);
            });

            this.modalContainer.querySelector("#notes-record-title-input")?.focus();

        },


        handleRecordSubmit(projectId, recordId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Record title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const notesStudio = this.getNotesStudio(project);

            const selectedSources = Array.from(form.querySelectorAll('[name="sourceIds"] option:checked'))
                .map(option => String(option.value || "").trim())
                .filter(Boolean);

            const selectedLinks = Array.from(form.querySelectorAll('[name="linkedEntityIds"] option:checked'))
                .map(option => String(option.value || "").trim())
                .filter(Boolean);

            const type = String(formData.get("typeSelect") || formData.get("type") || "Note").trim();

            const payload = {
                type: this.recordTypes.includes(type) ? type : "Note",
                title,
                content: String(formData.get("content") || ""),
                summary: String(formData.get("summary") || ""),
                category: String(formData.get("category") || "General").trim() || "General",
                tags: this.normalizeTags(String(formData.get("tags") || "")),
                status: String(formData.get("status") || "Draft").trim() || "Draft",
                priority: String(formData.get("priority") || "Medium").trim() || "Medium",
                sourceIds: selectedSources,
                linkedEntityIds: selectedLinks,
                updatedAt: new Date().toISOString()
            };

            const sourceLookup = new Set((notesStudio.sources || []).map(source => source.id));

            if (payload.sourceIds.some(sourceId => !sourceLookup.has(sourceId))) {
                this.core.notify("One or more selected sources are invalid.", "error");
                return;
            }

            if (!this.validateEntityTokens(project, notesStudio, payload.linkedEntityIds)) {
                this.core.notify("One or more linked entities are invalid or cross-project.", "error");
                return;
            }

            const saved = recordId
                ? this.updateRecord(projectId, recordId, payload)
                : this.createRecord(projectId, payload);

            if (!saved) {
                this.core.notify("Failed to save record.", "error");
                return;
            }

            this.closeModal();
            this.core.notify(`Record ${recordId ? "updated" : "created"}.`, "success");
            this.render(this.container);

        },


        showSourceModal(projectId, sourceId = null) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const notesStudio = this.getNotesStudio(project);

            const existing = sourceId
                ? (notesStudio.sources || []).find(source => source.id === sourceId) || null
                : null;

            if (sourceId && !existing) {
                this.core.notify("Source could not be found.", "error");
                return;
            }

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="notes-source-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">NOTES & RESEARCH</p>
                                <h2 id="notes-source-modal-title">${existing ? "Edit" : "New"} Source</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-notes-modal" aria-label="Close source form">×</button>
                        </header>

                        <form id="notes-source-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field form-field-wide" for="notes-source-title-input">
                                    <span>Title *</span>
                                    <input id="notes-source-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(existing?.title || "")}" />
                                </label>

                                <label class="form-field" for="notes-source-type-input">
                                    <span>Source Type</span>
                                    <select id="notes-source-type-input" name="sourceType">
                                        ${this.sourceTypes.map(type => `
                                            <option value="${this.escapeHTML(type)}" ${String(existing?.sourceType || "Other") === type ? "selected" : ""}>${this.escapeHTML(type)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="notes-source-author-input">
                                    <span>Author</span>
                                    <input id="notes-source-author-input" name="author" type="text" autocomplete="off" value="${this.escapeHTML(existing?.author || "")}" />
                                </label>

                                <label class="form-field" for="notes-source-publisher-input">
                                    <span>Publisher</span>
                                    <input id="notes-source-publisher-input" name="publisher" type="text" autocomplete="off" value="${this.escapeHTML(existing?.publisher || "")}" />
                                </label>

                                <label class="form-field" for="notes-source-publication-date-input">
                                    <span>Publication Date</span>
                                    <input id="notes-source-publication-date-input" name="publicationDate" type="text" autocomplete="off" value="${this.escapeHTML(existing?.publicationDate || "")}" />
                                </label>

                                <label class="form-field form-field-wide" for="notes-source-url-input">
                                    <span>URL</span>
                                    <input id="notes-source-url-input" name="url" type="url" autocomplete="off" value="${this.escapeHTML(existing?.url || "")}" />
                                </label>

                                <label class="form-field form-field-wide" for="notes-source-citation-input">
                                    <span>Citation</span>
                                    <textarea id="notes-source-citation-input" name="citation" rows="3">${this.escapeHTML(existing?.citation || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="notes-source-description-input">
                                    <span>Description</span>
                                    <textarea id="notes-source-description-input" name="description" rows="3">${this.escapeHTML(existing?.description || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="notes-source-notes-input">
                                    <span>Notes</span>
                                    <textarea id="notes-source-notes-input" name="notes" rows="4">${this.escapeHTML(existing?.notes || "")}</textarea>
                                </label>
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-notes-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${existing ? "Save Changes" : "Save Source"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-notes-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#notes-source-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleSourceSubmit(projectId, sourceId, event.currentTarget);
            });

            this.modalContainer.querySelector("#notes-source-title-input")?.focus();

        },


        handleSourceSubmit(projectId, sourceId, form) {

            const formData = new FormData(form);
            const title = String(formData.get("title") || "").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Source title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            const url = String(formData.get("url") || "").trim();

            if (url && !this.isValidSourceUrl(url)) {
                this.core.notify("Source URL must be a valid http/https URL.", "error");
                form.querySelector('[name="url"]')?.focus();
                return;
            }

            const payload = {
                title,
                author: String(formData.get("author") || ""),
                publisher: String(formData.get("publisher") || ""),
                publicationDate: String(formData.get("publicationDate") || ""),
                url,
                sourceType: String(formData.get("sourceType") || "Other"),
                citation: String(formData.get("citation") || ""),
                description: String(formData.get("description") || ""),
                notes: String(formData.get("notes") || ""),
                updatedAt: new Date().toISOString()
            };

            const saved = sourceId
                ? this.updateSource(projectId, sourceId, payload)
                : this.createSource(projectId, payload);

            if (!saved) {
                this.core.notify("Failed to save source.", "error");
                return;
            }

            this.closeModal();
            this.core.notify(`Source ${sourceId ? "updated" : "created"}.`, "success");
            this.render(this.container);

        },


        createRecord(projectId, payload) {

            return this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    const records = Array.isArray(notesStudio.records)
                        ? [...notesStudio.records]
                        : [];

                    const now = new Date().toISOString();
                    const candidate = {
                        ...payload,
                        id: AuthorOSHelpers.generateId("note_record"),
                        projectId,
                        createdAt: now,
                        updatedAt: now,
                        archivedAt: null
                    };

                    const normalized = this.normalizeRecord(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            records: [...records, normalized]
                        },
                        projectId,
                        this.getProjectTitle(this.getProjectById(projectId))
                    );

                },
                "notes-record-create",
                nextNotes => {

                    const latest = nextNotes.records[0] || null;

                    if (latest) {
                        this.selectedEntity = {
                            kind: "record",
                            id: latest.id
                        };
                    }

                }
            );

        },


        updateRecord(projectId, recordId, updates) {

            return this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    const records = Array.isArray(notesStudio.records)
                        ? [...notesStudio.records]
                        : [];

                    const index = records.findIndex(record => record.id === recordId);

                    if (index === -1) {
                        return null;
                    }

                    const existing = records[index];

                    const normalized = this.normalizeRecord(
                        {
                            ...existing,
                            ...updates,
                            id: existing.id,
                            projectId,
                            createdAt: existing.createdAt
                        },
                        projectId
                    );

                    if (!normalized) {
                        return null;
                    }

                    records[index] = normalized;

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            records
                        },
                        projectId,
                        this.getProjectTitle(this.getProjectById(projectId))
                    );

                },
                "notes-record-update",
                () => {
                    this.selectedEntity = {
                        kind: "record",
                        id: recordId
                    };
                }
            );

        },


        createSource(projectId, payload) {

            return this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    const sources = Array.isArray(notesStudio.sources)
                        ? [...notesStudio.sources]
                        : [];

                    const now = new Date().toISOString();

                    const candidate = {
                        ...payload,
                        id: AuthorOSHelpers.generateId("source"),
                        projectId,
                        createdAt: now,
                        updatedAt: now,
                        archivedAt: null
                    };

                    const normalized = this.normalizeSource(candidate, projectId);

                    if (!normalized) {
                        return null;
                    }

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            sources: [...sources, normalized]
                        },
                        projectId,
                        this.getProjectTitle(this.getProjectById(projectId))
                    );

                },
                "notes-source-create",
                nextNotes => {

                    const latest = nextNotes.sources[0] || null;

                    if (latest) {
                        this.selectedEntity = {
                            kind: "source",
                            id: latest.id
                        };
                    }

                }
            );

        },


        updateSource(projectId, sourceId, updates) {

            return this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    const sources = Array.isArray(notesStudio.sources)
                        ? [...notesStudio.sources]
                        : [];

                    const index = sources.findIndex(source => source.id === sourceId);

                    if (index === -1) {
                        return null;
                    }

                    const existing = sources[index];

                    const normalized = this.normalizeSource(
                        {
                            ...existing,
                            ...updates,
                            id: existing.id,
                            projectId,
                            createdAt: existing.createdAt
                        },
                        projectId
                    );

                    if (!normalized) {
                        return null;
                    }

                    sources[index] = normalized;

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            sources
                        },
                        projectId,
                        this.getProjectTitle(this.getProjectById(projectId))
                    );

                },
                "notes-source-update",
                () => {
                    this.selectedEntity = {
                        kind: "source",
                        id: sourceId
                    };
                }
            );

        },


        duplicateRecord(projectId, recordId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                return;
            }

            const notesStudio = this.getNotesStudio(project);
            const sourceLookup = new Set((notesStudio.sources || []).map(source => source.id));

            const source = (notesStudio.records || []).find(record => record.id === recordId);

            if (!source) {
                this.core.notify("Record could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();

            const duplicate = {
                ...source,
                id: AuthorOSHelpers.generateId("note_record"),
                title: `${source.title} - Copy`,
                status: source.status === "Archived" ? "Draft" : source.status,
                archivedAt: null,
                sourceIds: (source.sourceIds || []).filter(sourceId => sourceLookup.has(sourceId)),
                createdAt: now,
                updatedAt: now
            };

            const saved = this.createRecord(projectId, duplicate);

            if (!saved) {
                this.core.notify("Failed to duplicate record.", "error");
                return;
            }

            this.core.notify("Record duplicated.", "success");
            this.render(this.container);

        },


        duplicateSource(projectId, sourceId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                return;
            }

            const notesStudio = this.getNotesStudio(project);
            const source = (notesStudio.sources || []).find(item => item.id === sourceId);

            if (!source) {
                this.core.notify("Source could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();

            const duplicate = {
                ...source,
                id: AuthorOSHelpers.generateId("source"),
                title: `${source.title} - Copy`,
                archivedAt: null,
                createdAt: now,
                updatedAt: now
            };

            const saved = this.createSource(projectId, duplicate);

            if (!saved) {
                this.core.notify("Failed to duplicate source.", "error");
                return;
            }

            this.core.notify("Source duplicated.", "success");
            this.render(this.container);

        },


        archiveRecord(projectId, recordId) {

            const now = new Date().toISOString();

            const saved = this.updateRecord(
                projectId,
                recordId,
                {
                    status: "Archived",
                    archivedAt: now,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify("Failed to archive record.", "error");
                return;
            }

            this.core.notify("Record archived.", "success");
            this.render(this.container);

        },


        restoreRecord(projectId, recordId) {

            const now = new Date().toISOString();

            const saved = this.updateRecord(
                projectId,
                recordId,
                {
                    status: "Draft",
                    archivedAt: null,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify("Failed to restore record.", "error");
                return;
            }

            this.core.notify("Record restored.", "success");
            this.render(this.container);

        },


        archiveSource(projectId, sourceId) {

            const now = new Date().toISOString();

            const saved = this.updateSource(
                projectId,
                sourceId,
                {
                    archivedAt: now,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify("Failed to archive source.", "error");
                return;
            }

            this.core.notify("Source archived.", "success");
            this.render(this.container);

        },


        restoreSource(projectId, sourceId) {

            const now = new Date().toISOString();

            const saved = this.updateSource(
                projectId,
                sourceId,
                {
                    archivedAt: null,
                    updatedAt: now
                }
            );

            if (!saved) {
                this.core.notify("Failed to restore source.", "error");
                return;
            }

            this.core.notify("Source restored.", "success");
            this.render(this.container);

        },


        confirmDeleteRecord(projectId, recordId) {

            const project = this.getProjectById(projectId);
            const notesStudio = this.getNotesStudio(project);
            const record = (notesStudio.records || []).find(item => item.id === recordId);

            if (!record) {
                this.core.notify("Record could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete Record",
                content: `
                    <p>Delete \"${this.escapeHTML(record.title)}\"?</p>
                    <p>This deletes only this note/research record and does not affect manuscript, character, world, plot, or timeline data.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {

                    if (!this.deleteRecord(projectId, recordId)) {
                        this.core.notify("Failed to delete record.", "error");
                        return;
                    }

                    this.core.notify("Record deleted.", "success");
                    this.render(this.container);

                }
            });

        },


        deleteRecord(projectId, recordId) {

            return this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    const records = Array.isArray(notesStudio.records)
                        ? [...notesStudio.records]
                        : [];

                    const exists = records.some(record => record.id === recordId);

                    if (!exists) {
                        return null;
                    }

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            records: records.filter(record => record.id !== recordId)
                        },
                        projectId,
                        this.getProjectTitle(this.getProjectById(projectId))
                    );

                },
                "notes-record-delete",
                () => {

                    if (this.selectedEntity.kind === "record" && this.selectedEntity.id === recordId) {
                        this.selectedEntity = {
                            kind: "overview",
                            id: "overview"
                        };
                    }

                }
            );

        },


        confirmDeleteSource(projectId, sourceId) {

            const project = this.getProjectById(projectId);
            const notesStudio = this.getNotesStudio(project);
            const source = (notesStudio.sources || []).find(item => item.id === sourceId);

            if (!source) {
                this.core.notify("Source could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete Source",
                content: `
                    <p>Delete \"${this.escapeHTML(source.title)}\"?</p>
                    <p>This deletes only the source record. Linked notes/research entries will keep a missing-source label until edited.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {

                    if (!this.deleteSource(projectId, sourceId)) {
                        this.core.notify("Failed to delete source.", "error");
                        return;
                    }

                    this.core.notify("Source deleted.", "success");
                    this.render(this.container);

                }
            });

        },


        deleteSource(projectId, sourceId) {

            return this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    const sources = Array.isArray(notesStudio.sources)
                        ? [...notesStudio.sources]
                        : [];

                    const exists = sources.some(source => source.id === sourceId);

                    if (!exists) {
                        return null;
                    }

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            sources: sources.filter(source => source.id !== sourceId)
                        },
                        projectId,
                        this.getProjectTitle(this.getProjectById(projectId))
                    );

                },
                "notes-source-delete",
                () => {

                    if (this.selectedEntity.kind === "source" && this.selectedEntity.id === sourceId) {
                        this.selectedEntity = {
                            kind: "overview",
                            id: "overview"
                        };
                    }

                }
            );

        },


        exportNotesData(projectId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const notesStudio = this.getNotesStudio(project);

            const payload = {
                schemaVersion: 1,
                exportedAt: new Date().toISOString(),
                projectId,
                notesStudio
            };

            const fileName = `${this.getProjectTitle(project).replace(/[^a-z0-9]+/gi, "-").toLowerCase()}-notes-research.json`;

            const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
            const url = URL.createObjectURL(blob);

            const link = document.createElement("a");
            link.href = url;
            link.download = fileName;
            link.click();

            URL.revokeObjectURL(url);

            this.core.notify("Notes and research exported.", "success");

        },


        importNotesData(projectId, file) {

            if (!file) {
                return;
            }

            const reader = new FileReader();

            reader.onload = () => {

                let parsed = null;

                try {
                    parsed = JSON.parse(String(reader.result || "{}"));
                } catch (error) {
                    this.core.notify("Import failed: invalid JSON file.", "error");
                    return;
                }

                const imported = parsed?.notesStudio;

                if (!imported || typeof imported !== "object") {
                    this.core.notify("Import failed: file does not contain notesStudio data.", "error");
                    return;
                }

                this.confirmImport(projectId, imported);

            };

            reader.onerror = () => {
                this.core.notify("Import failed: unable to read file.", "error");
            };

            reader.readAsText(file);

        },


        confirmImport(projectId, importedNotesStudio) {

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Import confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Import Notes & Research",
                content: `
                    <p>Import records from file into the active project?</p>
                    <p>This appends imported records and sources with new IDs. Existing records are not overwritten.</p>
                `,
                confirmText: "Import",
                onConfirm: () => {

                    const result = this.mergeImportedNotesStudio(projectId, importedNotesStudio);

                    if (!result.ok) {
                        this.core.notify("Import failed.", "error");
                        return;
                    }

                    this.core.notify(`Imported ${result.records} records and ${result.sources} sources.`, "success");
                    this.render(this.container);

                }
            });

        },


        mergeImportedNotesStudio(projectId, importedNotesStudio) {

            const project = this.getProjectById(projectId);

            if (!project) {
                return {
                    ok: false,
                    records: 0,
                    sources: 0
                };
            }

            const normalizedIncoming = this.normalizeNotesStudio(importedNotesStudio, projectId, this.getProjectTitle(project));

            if (!normalizedIncoming) {
                return {
                    ok: false,
                    records: 0,
                    sources: 0
                };
            }

            const sourceIdMap = new Map();
            const now = new Date().toISOString();

            const remappedSources = normalizedIncoming.sources.map(source => {
                const newId = AuthorOSHelpers.generateId("source");
                sourceIdMap.set(source.id, newId);
                return {
                    ...source,
                    id: newId,
                    projectId,
                    archivedAt: null,
                    createdAt: now,
                    updatedAt: now
                };
            });

            const remappedRecords = normalizedIncoming.records.map(record => ({
                ...record,
                id: AuthorOSHelpers.generateId("note_record"),
                projectId,
                sourceIds: (record.sourceIds || [])
                    .map(sourceId => sourceIdMap.get(sourceId))
                    .filter(Boolean),
                linkedEntityIds: this.validateEntityTokens(project, this.getNotesStudio(project), record.linkedEntityIds || [])
                    ? (record.linkedEntityIds || [])
                    : [],
                status: record.status === "Archived" ? "Draft" : record.status,
                archivedAt: null,
                createdAt: now,
                updatedAt: now
            }));

            const saved = this.updateProjectNotesStudio(
                projectId,
                notesStudio => {

                    return this.normalizeNotesStudio(
                        {
                            ...notesStudio,
                            records: [...(notesStudio.records || []), ...remappedRecords],
                            sources: [...(notesStudio.sources || []), ...remappedSources]
                        },
                        projectId,
                        this.getProjectTitle(project)
                    );

                },
                "notes-import"
            );

            return {
                ok: Boolean(saved),
                records: remappedRecords.length,
                sources: remappedSources.length
            };

        },


        updateProjectNotesStudio(projectId, updater, source, onSuccess) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return false;
            }

            const hydrated = this.ensureProjectNotesShape(project);
            const nextProject = this.cloneData(hydrated.project);

            if (!nextProject) {
                return false;
            }

            const notesStudio = this.getNotesStudio(nextProject);
            const nextNotesStudio = updater(notesStudio);

            if (!nextNotesStudio || typeof nextNotesStudio !== "object") {
                return false;
            }

            const now = new Date().toISOString();

            nextProject.story.notesStudio = nextNotesStudio;

            const notesCount = (nextNotesStudio.records || []).filter(record => record.type === "Note").length;
            const researchCount = (nextNotesStudio.records || []).filter(record => record.type === "Research").length;
            const sourcesCount = (nextNotesStudio.sources || []).length;

            nextProject.statistics = {
                ...(nextProject.statistics || {}),
                notesCount,
                researchCount,
                sourcesCount
            };

            nextProject.updatedAt = now;
            nextProject.lastModified = now;

            if (!this.persistProject(nextProject, source || "notes-update")) {
                return false;
            }

            if (typeof onSuccess === "function") {
                onSuccess(nextNotesStudio);
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

                const saved = projectsModule.saveProjects(next, { source: source || "notes" });

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


        getUniqueTags(records) {

            const tags = new Set();

            (Array.isArray(records) ? records : []).forEach(record => {
                (Array.isArray(record.tags) ? record.tags : []).forEach(tag => {
                    if (String(tag || "").trim()) {
                        tags.add(String(tag).trim());
                    }
                });
            });

            return Array.from(tags).sort((left, right) => left.localeCompare(right, undefined, { sensitivity: "base" }));

        },


        getCategoryOptions(records) {

            const categories = new Set(this.categories);

            (Array.isArray(records) ? records : []).forEach(record => {
                const category = String(record.category || "").trim();
                if (category) {
                    categories.add(category);
                }
            });

            return Array.from(categories);

        },


        getSourceTypeOptions(sources) {

            const sourceTypes = new Set(this.sourceTypes);

            (Array.isArray(sources) ? sources : []).forEach(source => {
                const sourceType = String(source.sourceType || "").trim();
                if (sourceType) {
                    sourceTypes.add(sourceType);
                }
            });

            return Array.from(sourceTypes);

        },


        getEntityReferenceOptions(project, notesStudio) {

            const options = [];

            const add = (kind, id, label) => {
                if (!id) {
                    return;
                }

                options.push({
                    value: `${kind}:${id}`,
                    label: `${this.getEntityKindLabel(kind)}: ${label}`
                });
            };

            this.getProjectCharacters(project).forEach(character => {
                add("character", character.id, this.getCharacterName(character));
            });

            this.getProjectWorldEntries(project).forEach(entry => {
                add("world", entry.id, String(entry.title || "Untitled World Entry"));
            });

            const plot = this.getPlot(project);

            plot.arcs.forEach(arc => add("plotArc", arc.id, arc.title));
            plot.beats.forEach(beat => add("plotBeat", beat.id, beat.title));
            plot.scenes.forEach(scene => add("plotScene", scene.id, scene.title));

            const timeline = this.getTimeline(project);

            timeline.events.forEach(event => add("timelineEvent", event.id, event.title));

            this.getProjectChapters(project).forEach(chapter => {
                add("chapter", chapter.id, chapter.title);
            });

            if (project?.id) {
                add("project", project.id, this.getProjectTitle(project));
            }

            return options;

        },


        getEntityKindLabel(kind) {

            const labels = {
                character: "Character",
                world: "World",
                plotArc: "Plot Arc",
                plotBeat: "Plot Beat",
                plotScene: "Plot Scene",
                timelineEvent: "Timeline Event",
                chapter: "Chapter",
                project: "Project"
            };

            return labels[kind] || kind;

        },


        resolveEntityTokens(project, notesStudio, linkedEntityIds) {

            return (Array.isArray(linkedEntityIds) ? linkedEntityIds : []).map(token => {

                const [kind, id] = String(token || "").split(":");

                const target = this.resolveEntityTarget(project, notesStudio, kind, id);

                if (!target) {
                    return {
                        token,
                        kind,
                        kindLabel: this.getEntityKindLabel(kind),
                        label: `Missing ${this.getEntityKindLabel(kind).toLowerCase()} reference`,
                        missing: true
                    };
                }

                return {
                    token,
                    kind,
                    kindLabel: this.getEntityKindLabel(kind),
                    label: target.label,
                    missing: false
                };

            });

        },


        validateEntityTokens(project, notesStudio, linkedEntityIds) {

            return (Array.isArray(linkedEntityIds) ? linkedEntityIds : []).every(token => {

                const [kind, id] = String(token || "").split(":");

                if (!kind || !id) {
                    return false;
                }

                return Boolean(this.resolveEntityTarget(project, notesStudio, kind, id));

            });

        },


        resolveEntityTarget(project, notesStudio, kind, id) {

            if (!kind || !id) {
                return null;
            }

            if (kind === "character") {
                const character = this.getProjectCharacters(project).find(item => item.id === id);
                return character ? { label: this.getCharacterName(character), route: "characters" } : null;
            }

            if (kind === "world") {
                const entry = this.getProjectWorldEntries(project).find(item => item.id === id);
                return entry ? { label: String(entry.title || "Untitled World Entry"), route: "world" } : null;
            }

            const plot = this.getPlot(project);

            if (kind === "plotArc") {
                const arc = plot.arcs.find(item => item.id === id);
                return arc ? { label: arc.title, route: "plot" } : null;
            }

            if (kind === "plotBeat") {
                const beat = plot.beats.find(item => item.id === id);
                return beat ? { label: beat.title, route: "plot" } : null;
            }

            if (kind === "plotScene") {
                const scene = plot.scenes.find(item => item.id === id);
                return scene ? { label: scene.title, route: "plot" } : null;
            }

            const timeline = this.getTimeline(project);

            if (kind === "timelineEvent") {
                const event = timeline.events.find(item => item.id === id);
                return event ? { label: event.title, route: "timeline" } : null;
            }

            if (kind === "chapter") {
                const chapter = this.getProjectChapters(project).find(item => item.id === id);
                return chapter ? { label: chapter.title, route: "manuscript", chapterId: chapter.id } : null;
            }

            if (kind === "project") {
                return project?.id === id
                    ? { label: this.getProjectTitle(project), route: "project-workspace" }
                    : null;
            }

            return null;

        },


        openLinkedEntity(projectId, token) {

            const project = this.getProjectById(projectId);

            if (!project) {
                return;
            }

            const notesStudio = this.getNotesStudio(project);
            const [kind, id] = String(token || "").split(":");
            const target = this.resolveEntityTarget(project, notesStudio, kind, id);

            if (!target) {
                this.core.notify("Linked entity could not be found.", "error");
                return;
            }

            if (target.route === "manuscript" && target.chapterId) {

                const nextProject = this.cloneData(project);

                if (nextProject) {
                    if (!nextProject.manuscript || typeof nextProject.manuscript !== "object") {
                        nextProject.manuscript = {};
                    }
                    nextProject.manuscript.lastOpenedChapterId = target.chapterId;
                    nextProject.updatedAt = new Date().toISOString();
                    nextProject.lastModified = nextProject.updatedAt;
                    this.persistProject(nextProject, "notes-open-chapter");
                }

            }

            this.core.navigation.navigate(target.route);

        },


        isValidSourceUrl(value) {

            try {
                const parsed = new URL(value);
                return parsed.protocol === "http:" || parsed.protocol === "https:";
            } catch (error) {
                return false;
            }

        },


        getProjectCharacters(project) {

            return Array.isArray(project?.story?.characters)
                ? project.story.characters.filter(character => character && character.id)
                : [];

        },


        getCharacterName(character) {
            return String(character?.displayName || character?.name || "Unnamed Character").trim() || "Unnamed Character";
        },


        getProjectWorldEntries(project) {

            return Array.isArray(project?.story?.worldEntries)
                ? project.story.worldEntries.filter(entry => entry && entry.id)
                : [];

        },


        getPlot(project) {

            if (!project?.story?.plot || typeof project.story.plot !== "object") {
                return {
                    arcs: [],
                    beats: [],
                    scenes: []
                };
            }

            return {
                arcs: Array.isArray(project.story.plot.arcs) ? project.story.plot.arcs : [],
                beats: Array.isArray(project.story.plot.beats) ? project.story.plot.beats : [],
                scenes: Array.isArray(project.story.plot.scenes) ? project.story.plot.scenes : []
            };

        },


        getTimeline(project) {

            if (!project?.story?.timeline || typeof project.story.timeline !== "object" || Array.isArray(project.story.timeline)) {
                return {
                    events: []
                };
            }

            return {
                events: Array.isArray(project.story.timeline.events) ? project.story.timeline.events : []
            };

        },


        getProjectChapters(project) {

            return Array.isArray(project?.manuscript?.chapters)
                ? project.manuscript.chapters.filter(chapter => chapter && chapter.id)
                : [];

        },


        getEntryTitle(entry) {
            return String(entry?.title || entry?.data?.title || "Untitled").trim() || "Untitled";
        },


        truncate(value, max) {

            const text = String(value || "");

            if (text.length <= max) {
                return text;
            }

            return `${text.slice(0, max - 1)}...`;

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


        getNotesSummaryCounts(projectId = null) {

            const project = projectId
                ? this.getProjectById(projectId)
                : this.getActiveProject();

            if (!project) {
                return {
                    notes: 0,
                    research: 0,
                    sources: 0,
                    archived: 0
                };
            }

            const notesStudio = this.getNotesStudio(project);
            const records = Array.isArray(notesStudio.records) ? notesStudio.records : [];
            const sources = Array.isArray(notesStudio.sources) ? notesStudio.sources : [];

            return {
                notes: records.filter(record => record.type === "Note").length,
                research: records.filter(record => record.type === "Research").length,
                sources: sources.length,
                archived:
                    records.filter(record => String(record.status || "") === "Archived").length +
                    sources.filter(source => Boolean(source.archivedAt)).length
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
                console.error("Notes clone failed:", error);
                return null;
            }

        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();