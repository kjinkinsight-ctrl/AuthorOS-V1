/*
=========================================================
AUTHOROS
UNIVERSAL SEARCH MODULE
Milestone 11
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSUniversalSearch = {

        name: "universal-search",

        core: null,

        container: null,

        debounceTimer: null,

        uiState: {
            query: "",
            scope: "all-projects",
            includeArchived: false,
            sort: "relevance",
            type: "All",
            projectId: "All",
            series: "All",
            status: "All",
            category: "All",
            tag: "All"
        },

        resultState: {
            report: null,
            selectedIndex: -1,
            error: ""
        },

        initialize(core) {

            this.core = core;

            this.core.events.on("navigation:changed", nav => {

                if (nav?.route !== "search") {
                    return;
                }

                if (!this.container) {
                    return;
                }

                this.ensureScopeDefaults();
                this.runSearch(false);
                this.render(this.container);

                window.requestAnimationFrame(() => {
                    this.focusInput();
                });

            });

        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;

            this.ensureScopeDefaults();

            if (!this.resultState.report) {
                this.runSearch(false);
            }

            const report = this.resultState.report;
            const results = Array.isArray(report?.results) ? report.results : [];
            const facets = report?.facets || {
                types: [],
                projects: [],
                series: [],
                statuses: [],
                categories: [],
                tags: []
            };

            container.innerHTML = `
                <section class="search-view library-view">
                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">UNIVERSAL SEARCH</p>
                            <h1>Find Anything in Author Studio</h1>
                            <p class="library-description">
                                Search projects, series, ideas, manuscript chapters, characters, world, plot, timeline, notes, research, and sources.
                            </p>
                        </div>
                    </header>

                    <section class="search-input-shell" aria-label="Universal search input">
                        <div class="search-input-row">
                            <label for="global-search-query" class="visually-hidden">Search query</label>
                            <input
                                id="global-search-query"
                                class="search-query-input"
                                type="search"
                                autocomplete="off"
                                placeholder="Search Author Studio..."
                                value="${this.escapeHTML(this.uiState.query)}"
                                aria-describedby="search-help-text"
                            />
                            <button type="button" class="button button-secondary" data-action="submit-search">Search</button>
                            <button type="button" class="button button-secondary" data-action="clear-search">Clear</button>
                        </div>
                        <p id="search-help-text" class="search-help-text">
                            Shortcut: Ctrl/Cmd + K. Search is read-only and never edits story data.
                        </p>
                    </section>

                    ${this.renderControls(facets)}

                    <div class="library-results-bar search-results-bar" aria-live="polite" aria-atomic="true">
                        <span class="library-count">
                            ${report?.emptyQuery ? "Ready to search" : `${results.length} result${results.length === 1 ? "" : "s"}`}
                        </span>
                        ${this.resultState.error ? `<span class="search-error-text">${this.escapeHTML(this.resultState.error)}</span>` : ""}
                    </div>

                    ${report?.emptyQuery
                        ? this.renderEmptyQueryState()
                        : results.length
                            ? this.renderResults(results, report.query)
                            : this.renderNoResultsState()
                    }
                </section>
            `;

            this.bindEvents(container, results);

        },


        renderControls(facets) {

            return `
                <div class="library-controls search-controls">
                    <div class="library-filter-group">
                        <label for="search-scope-filter">Scope</label>
                        <select id="search-scope-filter" class="library-filter-select">
                            <option value="all-projects" ${this.uiState.scope === "all-projects" ? "selected" : ""}>All Projects</option>
                            ${this.getCurrentProjectId() ? `<option value="current-project" ${this.uiState.scope === "current-project" ? "selected" : ""}>Current Project</option>` : ""}
                            ${this.hasCurrentSeries() ? `<option value="current-series" ${this.uiState.scope === "current-series" ? "selected" : ""}>Current Series</option>` : ""}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-sort-filter">Sort</label>
                        <select id="search-sort-filter" class="library-filter-select">
                            <option value="relevance" ${this.uiState.sort === "relevance" ? "selected" : ""}>Relevance</option>
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently Updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently Created</option>
                            <option value="alpha" ${this.uiState.sort === "alpha" ? "selected" : ""}>Alphabetical</option>
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-type-filter">Type</label>
                        <select id="search-type-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.type === "All" ? "selected" : ""}>All Types</option>
                            ${facets.types.map(type => `<option value="${this.escapeHTML(type)}" ${this.uiState.type === type ? "selected" : ""}>${this.escapeHTML(type)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-project-filter">Project</label>
                        <select id="search-project-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.projectId === "All" ? "selected" : ""}>All Projects</option>
                            ${facets.projects.map(project => `<option value="${this.escapeHTML(project.id)}" ${this.uiState.projectId === project.id ? "selected" : ""}>${this.escapeHTML(project.name)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-series-filter">Series</label>
                        <select id="search-series-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.series === "All" ? "selected" : ""}>All Series</option>
                            ${facets.series.map(series => `<option value="${this.escapeHTML(series)}" ${this.uiState.series === series ? "selected" : ""}>${this.escapeHTML(series)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-status-filter">Status</label>
                        <select id="search-status-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.status === "All" ? "selected" : ""}>All Statuses</option>
                            ${facets.statuses.map(status => `<option value="${this.escapeHTML(status)}" ${this.uiState.status === status ? "selected" : ""}>${this.escapeHTML(status)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-category-filter">Category</label>
                        <select id="search-category-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.category === "All" ? "selected" : ""}>All Categories</option>
                            ${facets.categories.map(category => `<option value="${this.escapeHTML(category)}" ${this.uiState.category === category ? "selected" : ""}>${this.escapeHTML(category)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="search-tag-filter">Tag</label>
                        <select id="search-tag-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.tag === "All" ? "selected" : ""}>All Tags</option>
                            ${facets.tags.map(tag => `<option value="${this.escapeHTML(tag)}" ${this.uiState.tag === tag ? "selected" : ""}>${this.escapeHTML(tag)}</option>`).join("")}
                        </select>
                    </div>

                    <label class="search-archived-toggle" for="search-archived-toggle">
                        <input id="search-archived-toggle" type="checkbox" ${this.uiState.includeArchived ? "checked" : ""} />
                        Include archived
                    </label>

                    <button type="button" class="library-clear-filters" data-action="clear-search-filters">Clear Filters</button>
                </div>
            `;

        },


        renderEmptyQueryState() {

            const recent = this.getSearchService().getRecentQueries();

            return `
                <section class="library-empty-state search-empty-state">
                    <div class="empty-state-icon">⌕</div>
                    <h2>Search across all writing data</h2>
                    <p>Enter a term to search titles, content, tags, statuses, and metadata.</p>

                    ${recent.length
                        ? `
                            <section class="search-recent-queries" aria-label="Recent searches">
                                <h3>Recent Searches</h3>
                                <div class="search-recent-list">
                                    ${recent.map(query => `<button type="button" class="button button-secondary" data-action="run-recent-search" data-query="${this.escapeHTML(query)}">${this.escapeHTML(query)}</button>`).join("")}
                                </div>
                                <button type="button" class="button button-secondary" data-action="clear-recent-searches">Clear Recent Searches</button>
                            </section>
                        `
                        : ""
                    }
                </section>
            `;

        },


        renderNoResultsState() {

            return `
                <section class="library-empty-state search-empty-state">
                    <div class="empty-state-icon">∅</div>
                    <h2>No results found</h2>
                    <p>Try a different search term or clear your filters.</p>
                    <div class="notes-empty-actions">
                        <button type="button" class="button button-secondary" data-action="clear-search">Clear Search</button>
                        <button type="button" class="button button-secondary" data-action="clear-search-filters">Clear Filters</button>
                    </div>
                </section>
            `;

        },


        renderResults(results, query) {

            return `
                <section class="search-results-list" role="list" aria-label="Universal search results">
                    ${results.map((result, index) => this.renderResultCard(result, query, index)).join("")}
                </section>
            `;

        },


        renderResultCard(result, query, index) {

            const context = [
                result.projectName ? `Project: ${result.projectName}` : "",
                result.series ? `Series: ${result.series}` : ""
            ].filter(Boolean).join(" | ");

            const metadata = [
                result.metadata.status ? `Status: ${result.metadata.status}` : "",
                result.metadata.category ? `Category: ${result.metadata.category}` : "",
                result.metadata.priority ? `Priority: ${result.metadata.priority}` : "",
                result.metadata.tags && result.metadata.tags.length ? `Tags: ${result.metadata.tags.join(", ")}` : "",
                result.metadata.updatedAt ? `Updated: ${this.formatDate(result.metadata.updatedAt)}` : ""
            ].filter(Boolean).join(" | ");

            const selected = index === this.resultState.selectedIndex;

            return `
                <article class="project-card search-result-card ${selected ? "selected" : ""}" role="listitem" tabindex="0" data-result-index="${index}" data-result-key="${this.escapeHTML(result.key)}">
                    <div class="project-card-body">
                        <header class="search-result-header">
                            <span class="search-result-type">${this.escapeHTML(result.entityType)}</span>
                            ${result.archived ? `<span class="search-result-archived">Archived</span>` : ""}
                        </header>

                        <h2 class="search-result-title">${this.getSearchService().highlightMatches(result.title, query)}</h2>

                        ${context ? `<p class="search-result-context">${this.escapeHTML(context)}</p>` : ""}
                        ${metadata ? `<p class="search-result-metadata">${this.escapeHTML(metadata)}</p>` : ""}

                        <p class="search-result-preview">${this.getSearchService().highlightMatches(result.preview, query)}</p>

                        <div class="search-result-footer">
                            <span class="search-result-matched-field">Matched in ${this.escapeHTML(result.matchedField || "Content")}</span>
                            <button type="button" class="button button-secondary" data-action="open-search-result" data-result-key="${this.escapeHTML(result.key)}">Open</button>
                        </div>
                    </div>
                </article>
            `;

        },


        bindEvents(container, results) {

            const input = container.querySelector("#global-search-query");

            input?.addEventListener("input", () => {
                this.uiState.query = String(input.value || "");
                this.scheduleLiveSearch();
            });

            input?.addEventListener("keydown", event => {

                if (event.key === "Enter") {
                    event.preventDefault();
                    this.runSearch(true);
                    this.render(this.container);
                    return;
                }

                if (event.key === "ArrowDown") {
                    event.preventDefault();
                    this.moveSelection(1, results.length);
                    this.render(this.container);
                    return;
                }

                if (event.key === "ArrowUp") {
                    event.preventDefault();
                    this.moveSelection(-1, results.length);
                    this.render(this.container);
                    return;
                }

            });

            container.querySelector('[data-action="submit-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.runSearch(true);
                this.render(this.container);
            });

            container.querySelectorAll('[data-action="clear-search"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.uiState.query = "";
                    this.resultState.selectedIndex = -1;
                    this.resultState.error = "";
                    this.runSearch(false);
                    this.render(this.container);
                });
            });

            container.querySelector('[data-action="clear-search-filters"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.clearFilters();
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-scope-filter')?.addEventListener("change", event => {
                this.uiState.scope = String(event.currentTarget.value || "all-projects");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-sort-filter')?.addEventListener("change", event => {
                this.uiState.sort = String(event.currentTarget.value || "relevance");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-type-filter')?.addEventListener("change", event => {
                this.uiState.type = String(event.currentTarget.value || "All");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-project-filter')?.addEventListener("change", event => {
                this.uiState.projectId = String(event.currentTarget.value || "All");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-series-filter')?.addEventListener("change", event => {
                this.uiState.series = String(event.currentTarget.value || "All");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-status-filter')?.addEventListener("change", event => {
                this.uiState.status = String(event.currentTarget.value || "All");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-category-filter')?.addEventListener("change", event => {
                this.uiState.category = String(event.currentTarget.value || "All");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-tag-filter')?.addEventListener("change", event => {
                this.uiState.tag = String(event.currentTarget.value || "All");
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelector('#search-archived-toggle')?.addEventListener("change", event => {
                this.uiState.includeArchived = Boolean(event.currentTarget.checked);
                this.runSearch(false);
                this.render(this.container);
            });

            container.querySelectorAll('[data-action="open-search-result"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openResultByKey(button.dataset.resultKey);
                });
            });

            container.querySelectorAll('.search-result-card').forEach(card => {

                card.addEventListener("click", () => {
                    const index = Number(card.dataset.resultIndex || -1);

                    if (Number.isFinite(index) && index >= 0) {
                        this.resultState.selectedIndex = index;
                        this.render(this.container);
                    }
                });

                card.addEventListener("keydown", event => {

                    if (event.key === "Enter") {
                        event.preventDefault();
                        this.openResultByKey(card.dataset.resultKey);
                        return;
                    }

                    if (event.key === "ArrowDown") {
                        event.preventDefault();
                        this.moveSelection(1, results.length);
                        this.render(this.container);
                        return;
                    }

                    if (event.key === "ArrowUp") {
                        event.preventDefault();
                        this.moveSelection(-1, results.length);
                        this.render(this.container);
                    }

                });

            });

            container.querySelectorAll('[data-action="run-recent-search"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.uiState.query = String(button.dataset.query || "");
                    this.runSearch(true);
                    this.render(this.container);
                });
            });

            container.querySelector('[data-action="clear-recent-searches"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.getSearchService().clearRecentQueries();
                this.render(this.container);
            });

        },


        moveSelection(delta, count) {

            if (!count) {
                this.resultState.selectedIndex = -1;
                return;
            }

            const current = Number(this.resultState.selectedIndex);

            if (!Number.isFinite(current) || current < 0) {
                this.resultState.selectedIndex = delta > 0 ? 0 : count - 1;
                return;
            }

            const next = (current + delta + count) % count;
            this.resultState.selectedIndex = next;

        },


        scheduleLiveSearch() {

            window.clearTimeout(this.debounceTimer);

            this.debounceTimer = window.setTimeout(() => {
                this.runSearch(false);
                this.render(this.container);
            }, 140);

        },


        runSearch(saveRecent) {

            try {

                const service = this.getSearchService();

                const report = service.searchUniversal(this.uiState.query, {
                    scope: this.uiState.scope,
                    sort: this.uiState.sort,
                    includeArchived: this.uiState.includeArchived,
                    type: this.uiState.type,
                    projectId: this.uiState.projectId,
                    series: this.uiState.series,
                    status: this.uiState.status,
                    category: this.uiState.category,
                    tag: this.uiState.tag
                });

                if (saveRecent && !report.emptyQuery) {
                    service.saveRecentQuery(this.uiState.query);
                }

                this.resultState.report = report;
                this.resultState.error = "";

                const maxIndex = (report.results || []).length - 1;

                if (this.resultState.selectedIndex > maxIndex) {
                    this.resultState.selectedIndex = maxIndex;
                }

                if ((report.results || []).length === 0) {
                    this.resultState.selectedIndex = -1;
                }

            } catch (error) {

                console.error("Universal search failed:", error);

                this.resultState.report = {
                    query: this.getSearchService().normalizeQuery(this.uiState.query),
                    emptyQuery: false,
                    results: [],
                    facets: {
                        types: [],
                        projects: [],
                        series: [],
                        statuses: [],
                        categories: [],
                        tags: []
                    }
                };

                this.resultState.error = "Search failed. Please try again.";
            }

        },


        openResultByKey(resultKey) {

            const report = this.resultState.report;
            const result = (report?.results || []).find(item => item.key === resultKey) || null;

            if (!result) {
                this.resultState.error = "Selected result is no longer available.";
                this.render(this.container);
                return;
            }

            const openStatus = this.getSearchService().openResult(result);

            if (!openStatus.ok) {
                this.resultState.error = openStatus.message || "Unable to open this result.";
                this.render(this.container);
                return;
            }

            this.getSearchService().saveRecentQuery(this.uiState.query);

        },


        clearFilters() {

            this.uiState.type = "All";
            this.uiState.projectId = "All";
            this.uiState.series = "All";
            this.uiState.status = "All";
            this.uiState.category = "All";
            this.uiState.tag = "All";
            this.uiState.sort = "relevance";
            this.uiState.includeArchived = false;

        },


        ensureScopeDefaults() {

            const currentProjectId = this.getCurrentProjectId();

            if (this.uiState.scope === "current-project" && !currentProjectId) {
                this.uiState.scope = "all-projects";
            }

            if (this.uiState.scope === "current-series" && !this.hasCurrentSeries()) {
                this.uiState.scope = currentProjectId ? "current-project" : "all-projects";
            }

        },


        hasCurrentSeries() {

            const currentProject = this.core.state.get("currentProject");
            const series = String(currentProject?.series || "").trim();

            return Boolean(series);

        },


        getCurrentProjectId() {

            const currentProject = this.core.state.get("currentProject");

            if (currentProject?.id) {
                return currentProject.id;
            }

            return this.core.storage.loadActiveProjectId() || "";

        },


        getSearchService() {
            return this.core.searchService || this.core.search || this.core.app?.search;
        },


        focusInput() {
            this.container?.querySelector("#global-search-query")?.focus();
        },


        formatDate(value) {

            if (!value) {
                return "Unknown";
            }

            const date = new Date(value);

            if (Number.isNaN(date.getTime())) {
                return "Unknown";
            }

            return date.toLocaleString();

        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
