/*
=========================================================
AUTHOROS
STATISTICS STUDIO MODULE
Milestone 12
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSStatistics = {

        name: "statistics",

        core: null,

        container: null,

        uiState: {
            scope: "current-project",
            projectId: "",
            series: ""
        },

        initialize(core) {

            this.core = core;

            this.core.events.on("navigation:changed", nav => {

                if (nav?.route !== "statistics") {
                    return;
                }

                if (!this.container) {
                    return;
                }

                this.ensureDefaults();
                this.render(this.container);

            });

        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;

            this.ensureDefaults();

            const projects = this.getProjects();

            if (!projects.length) {
                container.innerHTML = this.renderMissingDataState();
                container.querySelector('[data-action="open-story-library"]')?.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("projects");
                });
                return;
            }

            const service = this.getService();

            let bundle = null;

            try {
                bundle = service.getScopeBundle({
                    scope: this.uiState.scope,
                    projectId: this.uiState.projectId,
                    series: this.uiState.series
                });
            } catch (error) {
                console.error("Statistics Studio render failed:", error);
                container.innerHTML = this.renderErrorState();
                return;
            }

            container.innerHTML = `
                <section class="statistics-view library-view">
                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">STATISTICS STUDIO</p>
                            <h1>Writing Statistics</h1>
                            <p class="library-description">
                                Read-only analytics derived from canonical project data.
                            </p>
                        </div>
                    </header>

                    ${this.renderScopeControls(bundle)}

                    ${this.renderSummaryCards(bundle)}

                    <div class="statistics-grid">
                        ${this.renderManuscriptPanel(bundle)}
                        ${this.renderGoalPanel(bundle)}
                        ${this.renderActivityPanel(bundle)}
                        ${this.renderProjectRollupPanel(bundle)}
                        ${this.renderChapterPanel(bundle)}
                        ${this.renderDistributionsPanel(bundle)}
                    </div>
                </section>
            `;

            this.bindEvents(container, bundle);

        },


        renderMissingDataState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">◍</div>
                    <p class="eyebrow">STATISTICS STUDIO</p>
                    <h1>No project data available</h1>
                    <p>Create or open a project in Story Library to view statistics.</p>
                    <div class="manuscript-missing-actions">
                        <button type="button" class="button button-primary" data-action="open-story-library">Open Story Library</button>
                    </div>
                </section>
            `;

        },


        renderErrorState() {

            return `
                <section class="library-empty-state">
                    <div class="empty-state-icon">!</div>
                    <h2>Statistics unavailable</h2>
                    <p>Statistics could not be calculated from current data.</p>
                </section>
            `;

        },


        renderScopeControls(bundle) {

            const currentProjectId = this.getCurrentProjectId();
            const projectOptions = this.getProjects()
                .filter(project => String(project?.status || "") !== "Archived");

            const seriesOptions = this.getSeriesOptions();

            return `
                <div class="library-controls statistics-controls">
                    <div class="library-filter-group">
                        <label for="statistics-scope">Scope</label>
                        <select id="statistics-scope" class="library-filter-select">
                            <option value="current-project" ${this.uiState.scope === "current-project" ? "selected" : ""}>Current Project</option>
                            <option value="current-series" ${this.uiState.scope === "current-series" ? "selected" : ""} ${this.hasCurrentSeries() ? "" : "disabled"}>Current Series</option>
                            <option value="all-projects" ${this.uiState.scope === "all-projects" ? "selected" : ""}>All Projects</option>
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="statistics-project">Project</label>
                        <select id="statistics-project" class="library-filter-select">
                            <option value="" ${!this.uiState.projectId ? "selected" : ""}>Current Active Project</option>
                            ${projectOptions.map(project => `
                                <option value="${this.escapeHTML(project.id)}" ${this.uiState.projectId === project.id ? "selected" : ""}>${this.escapeHTML(this.getProjectName(project))}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="statistics-series">Series</label>
                        <select id="statistics-series" class="library-filter-select">
                            <option value="" ${!this.uiState.series ? "selected" : ""}>Current Series</option>
                            ${seriesOptions.map(series => `
                                <option value="${this.escapeHTML(series)}" ${this.uiState.series === series ? "selected" : ""}>${this.escapeHTML(series)}</option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="statistics-readonly-pill" aria-label="Read-only analytics">
                        Read-only calculations
                    </div>
                </div>

                <div class="library-results-bar statistics-context-row">
                    <span class="library-count">${bundle.projectCount} project${bundle.projectCount === 1 ? "" : "s"} in scope</span>
                    ${bundle.summary.updatedAt ? `<span class="library-filter-state">Last updated ${this.formatDate(bundle.summary.updatedAt)}</span>` : ""}
                </div>
            `;

        },


        renderSummaryCards(bundle) {

            const summary = bundle.summary;

            const cards = [
                { label: "Total Words", value: this.number(summary.words) },
                { label: "Chapters", value: this.number(summary.chapters) },
                { label: "Scenes", value: this.number(summary.scenes) },
                { label: "Characters", value: this.number(summary.characters) },
                { label: "World Entries", value: this.number(summary.worldEntries) },
                { label: "Plot Items", value: this.number(summary.plotItems) },
                { label: "Timeline Events", value: this.number(summary.timelineEvents) },
                { label: "Notes", value: this.number(summary.notes) },
                { label: "Research", value: this.number(summary.research) },
                { label: "Sources", value: this.number(summary.sources) }
            ];

            return `
                <section class="statistics-summary-grid" aria-label="Statistics summary cards">
                    ${cards.map(card => `
                        <article class="statistics-summary-card">
                            <h3>${this.escapeHTML(card.label)}</h3>
                            <p>${this.escapeHTML(card.value)}</p>
                        </article>
                    `).join("")}
                </section>
            `;

        },


        renderManuscriptPanel(bundle) {

            const manuscript = bundle.manuscript;
            const chapters = bundle.chapters;

            return `
                <article class="statistics-panel">
                    <header class="statistics-panel-header">
                        <h2>Manuscript Metrics</h2>
                    </header>

                    <dl class="statistics-kv-grid">
                        <div><dt>Total words</dt><dd>${this.number(manuscript.totalWords)}</dd></div>
                        <div><dt>Chapter count</dt><dd>${this.number(manuscript.chapterCount)}</dd></div>
                        <div><dt>Scene count</dt><dd>${this.number(manuscript.sceneCount)}</dd></div>
                        <div><dt>Average chapter words</dt><dd>${this.number(manuscript.averageChapterWords)}</dd></div>
                        <div><dt>Min chapter words</dt><dd>${this.number(chapters.minWords)}</dd></div>
                        <div><dt>Max chapter words</dt><dd>${this.number(chapters.maxWords)}</dd></div>
                    </dl>

                    <div class="statistics-subnote">
                        <p>${this.escapeHTML(manuscript.chapterStatusMessage)}</p>
                        <p>${this.escapeHTML(manuscript.sceneWordMetricsMessage)}</p>
                    </div>
                </article>
            `;

        },


        renderGoalPanel(bundle) {

            const goals = bundle.goals;

            if (!goals.available) {
                return `
                    <article class="statistics-panel">
                        <header class="statistics-panel-header">
                            <h2>Writing Goals</h2>
                        </header>
                        <p class="statistics-empty-text">No goal targets are currently set in canonical project data.</p>
                    </article>
                `;
            }

            return `
                <article class="statistics-panel">
                    <header class="statistics-panel-header">
                        <h2>Writing Goals</h2>
                    </header>

                    <dl class="statistics-kv-grid">
                        <div><dt>Goal target</dt><dd>${this.number(goals.totalTarget)}</dd></div>
                        <div><dt>Current progress</dt><dd>${this.number(goals.totalCurrent)}</dd></div>
                        <div><dt>Remaining words</dt><dd>${this.number(goals.remaining)}</dd></div>
                        <div><dt>Complete</dt><dd>${goals.percent}%</dd></div>
                    </dl>

                    <progress class="statistics-progress" max="100" value="${goals.percent}" aria-label="Writing goal progress"></progress>

                    <p class="statistics-chart-summary">
                        Goal summary: ${this.number(goals.totalCurrent)} of ${this.number(goals.totalTarget)} words (${goals.percent}%).
                    </p>

                    ${goals.projectsWithGoals.length > 1
                        ? `
                            <ul class="statistics-inline-list">
                                ${goals.projectsWithGoals.map(item => `
                                    <li>${this.escapeHTML(item.projectName)}: ${this.number(item.current)} / ${this.number(item.target)}</li>
                                `).join("")}
                            </ul>
                        `
                        : ""
                    }
                </article>
            `;

        },


        renderActivityPanel(bundle) {

            const activity = bundle.activity;

            return `
                <article class="statistics-panel">
                    <header class="statistics-panel-header">
                        <h2>Writing Activity</h2>
                    </header>

                    <dl class="statistics-kv-grid">
                        <div><dt>Active writing days</dt><dd>${this.number(activity.activeWritingDays)}</dd></div>
                        <div><dt>Chapter updates (7d)</dt><dd>${this.number(activity.chapterUpdatesLast7Days)}</dd></div>
                        <div><dt>Chapter updates (30d)</dt><dd>${this.number(activity.chapterUpdatesLast30Days)}</dd></div>
                        <div><dt>Latest chapter update</dt><dd>${activity.latestChapterUpdate ? this.escapeHTML(this.formatDate(activity.latestChapterUpdate)) : "Unavailable"}</dd></div>
                    </dl>

                    <p class="statistics-subnote">${this.escapeHTML(activity.historicalWordGrowthMessage)}</p>
                </article>
            `;

        },


        renderProjectRollupPanel(bundle) {

            const summary = bundle.summary;

            return `
                <article class="statistics-panel">
                    <header class="statistics-panel-header">
                        <h2>Project and Series Rollup</h2>
                    </header>

                    <dl class="statistics-kv-grid">
                        <div><dt>Projects in scope</dt><dd>${this.number(summary.projectCount)}</dd></div>
                        <div><dt>Total words</dt><dd>${this.number(summary.words)}</dd></div>
                        <div><dt>Total chapters</dt><dd>${this.number(summary.chapters)}</dd></div>
                        <div><dt>Total scenes</dt><dd>${this.number(summary.scenes)}</dd></div>
                    </dl>

                    ${this.renderSeriesTable(bundle.seriesRollup)}
                </article>
            `;

        },


        renderSeriesTable(seriesRollup) {

            const names = Object.keys(seriesRollup || {});

            if (!names.length) {
                return "<p class=\"statistics-empty-text\">No series rollup data in current scope.</p>";
            }

            return `
                <div class="statistics-table-wrap">
                    <table class="statistics-table">
                        <thead>
                            <tr>
                                <th>Series</th>
                                <th>Books</th>
                                <th>Total Words</th>
                                <th>Chapters</th>
                                <th>Scenes</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${names.sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" })).map(name => {
                                const item = seriesRollup[name];
                                return `
                                    <tr>
                                        <td>${this.escapeHTML(name)}</td>
                                        <td>${this.number(item.projectCount)}</td>
                                        <td>${this.number(item.words)}</td>
                                        <td>${this.number(item.chapters)}</td>
                                        <td>${this.number(item.scenes)}</td>
                                    </tr>
                                `;
                            }).join("")}
                        </tbody>
                    </table>
                </div>
            `;

        },


        renderChapterPanel(bundle) {

            const chapters = bundle.chapters;

            return `
                <article class="statistics-panel statistics-panel-wide">
                    <header class="statistics-panel-header">
                        <h2>Chapter Statistics</h2>
                    </header>

                    ${chapters.rows.length
                        ? `
                            <div class="statistics-table-wrap">
                                <table class="statistics-table">
                                    <thead>
                                        <tr>
                                            <th>Project</th>
                                            <th>Chapter</th>
                                            <th>Order</th>
                                            <th>Words</th>
                                            <th>Scenes</th>
                                            <th>Status</th>
                                            <th>Updated</th>
                                            <th>Action</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${chapters.rows.map(row => `
                                            <tr>
                                                <td>${this.escapeHTML(row.projectName)}</td>
                                                <td>${this.escapeHTML(row.title)}</td>
                                                <td>${this.number(row.order)}</td>
                                                <td>${this.number(row.words)}</td>
                                                <td>${this.number(row.completeScenes)}/${this.number(row.sceneCount)}</td>
                                                <td>${this.escapeHTML(row.status)}</td>
                                                <td>${row.updatedAt ? this.escapeHTML(this.formatDate(row.updatedAt)) : "Unavailable"}</td>
                                                <td>
                                                    <button
                                                        type="button"
                                                        class="button button-secondary statistics-open-chapter"
                                                        data-action="open-stat-chapter"
                                                        data-project-id="${this.escapeHTML(row.projectId)}"
                                                        data-chapter-id="${this.escapeHTML(row.chapterId)}"
                                                    >
                                                        Open
                                                    </button>
                                                </td>
                                            </tr>
                                        `).join("")}
                                    </tbody>
                                </table>
                            </div>
                        `
                        : "<p class=\"statistics-empty-text\">No chapter data in current scope.</p>"
                    }
                </article>
            `;

        },


        renderDistributionsPanel(bundle) {

            return `
                <article class="statistics-panel statistics-panel-wide">
                    <header class="statistics-panel-header">
                        <h2>Distributions</h2>
                    </header>

                    <div class="statistics-chart-grid">
                        ${this.renderMiniChart("Character roles", bundle.characters.byRole)}
                        ${this.renderMiniChart("Character status", bundle.characters.byStatus)}
                        ${this.renderMiniChart("World categories", bundle.world.byType)}
                        ${this.renderMiniChart("World status", bundle.world.byStatus)}
                        ${this.renderMiniChart("Plot scene status", bundle.plot.sceneByStatus)}
                        ${this.renderMiniChart("Timeline event types", bundle.timeline.byType)}
                        ${this.renderMiniChart("Timeline status", bundle.timeline.byStatus)}
                        ${this.renderMiniChart("Notes by category", bundle.notes.byCategory)}
                        ${this.renderMiniChart("Notes status", bundle.notes.byStatus)}
                    </div>

                    <div class="statistics-kv-grid statistics-kv-grid-compact">
                        <div><dt>Plot arcs</dt><dd>${this.number(bundle.plot.arcs)}</dd></div>
                        <div><dt>Plot acts</dt><dd>${this.number(bundle.plot.acts)}</dd></div>
                        <div><dt>Plot beats</dt><dd>${this.number(bundle.plot.beats)}</dd></div>
                        <div><dt>Plot threads</dt><dd>${this.number(bundle.plot.threads)}</dd></div>
                        <div><dt>Plot scenes</dt><dd>${this.number(bundle.plot.scenes)}</dd></div>
                        <div><dt>Scene complete</dt><dd>${this.number(bundle.plot.completeScenes)}</dd></div>
                        <div><dt>Timeline events</dt><dd>${this.number(bundle.timeline.events)}</dd></div>
                        <div><dt>Timeline eras</dt><dd>${this.number(bundle.timeline.eras)}</dd></div>
                        <div><dt>Timeline sequences</dt><dd>${this.number(bundle.timeline.sequences)}</dd></div>
                        <div><dt>Timeline warnings</dt><dd>${this.number(bundle.timeline.warnings)}</dd></div>
                        <div><dt>Notes</dt><dd>${this.number(bundle.notes.notes)}</dd></div>
                        <div><dt>Research</dt><dd>${this.number(bundle.notes.research)}</dd></div>
                        <div><dt>Sources</dt><dd>${this.number(bundle.notes.sources)}</dd></div>
                    </div>
                </article>
            `;

        },


        renderMiniChart(title, dataMap) {

            const entries = Object.entries(dataMap || {})
                .sort((left, right) => right[1] - left[1])
                .slice(0, 8);

            if (!entries.length) {
                return `
                    <section class="statistics-chart-card">
                        <h3>${this.escapeHTML(title)}</h3>
                        <p class="statistics-empty-text">No data</p>
                    </section>
                `;
            }

            const max = Math.max(...entries.map(([, count]) => Number(count || 0)), 1);

            return `
                <section class="statistics-chart-card">
                    <h3>${this.escapeHTML(title)}</h3>
                    <ul class="statistics-chart-list">
                        ${entries.map(([label, count]) => {
                            const safeCount = Number(count || 0);
                            const width = Math.max(2, Math.round((safeCount / max) * 100));
                            return `
                                <li>
                                    <span class="statistics-chart-label">${this.escapeHTML(label)}</span>
                                    <span class="statistics-chart-bar-wrap" aria-hidden="true">
                                        <span class="statistics-chart-bar" style="width:${width}%"></span>
                                    </span>
                                    <span class="statistics-chart-value">${this.number(safeCount)}</span>
                                </li>
                            `;
                        }).join("")}
                    </ul>
                    <p class="statistics-chart-summary">
                        ${this.escapeHTML(title)} summary: ${entries.map(([label, count]) => `${label} (${this.number(count)})`).join(", ")}.
                    </p>
                </section>
            `;

        },


        bindEvents(container, bundle) {

            container.querySelector("#statistics-scope")?.addEventListener("change", event => {
                this.uiState.scope = String(event.currentTarget.value || "current-project");
                this.ensureDefaults();
                this.render(this.container);
            });

            container.querySelector("#statistics-project")?.addEventListener("change", event => {
                this.uiState.projectId = String(event.currentTarget.value || "");
                this.ensureDefaults();
                this.render(this.container);
            });

            container.querySelector("#statistics-series")?.addEventListener("change", event => {
                this.uiState.series = String(event.currentTarget.value || "");
                this.ensureDefaults();
                this.render(this.container);
            });

            container.querySelectorAll('[data-action="open-stat-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openChapterFromStatistics(button.dataset.projectId, button.dataset.chapterId);
                });
            });

        },


        openChapterFromStatistics(projectId, chapterId) {

            if (!projectId || !chapterId) {
                return;
            }

            const project = this.getProjects().find(item => item.id === projectId) || null;

            if (!project) {
                this.core.notify("Chapter target project could not be found.", "error");
                return;
            }

            this.core.state.set("currentProject", project);
            this.core.storage.saveActiveProjectId(projectId);

            const manuscriptModule = this.core.registry.get("manuscript");

            if (manuscriptModule) {
                manuscriptModule.activeChapterId = chapterId;
            }

            this.core.navigation.navigate("manuscript");

        },


        ensureDefaults() {

            const currentProject = this.core.state.get("currentProject");

            if (!this.uiState.projectId && currentProject?.id) {
                this.uiState.projectId = currentProject.id;
            }

            if (!this.uiState.series) {
                this.uiState.series = String(currentProject?.series || "").trim();
            }

            if (this.uiState.scope === "current-series" && !this.hasCurrentSeries() && !this.uiState.series) {
                this.uiState.scope = this.uiState.projectId ? "current-project" : "all-projects";
            }

            if (this.uiState.scope === "current-project" && !this.uiState.projectId) {
                this.uiState.scope = "all-projects";
            }

        },


        hasCurrentSeries() {
            const currentProject = this.core.state.get("currentProject");
            return Boolean(String(currentProject?.series || "").trim());
        },


        getCurrentProjectId() {
            const currentProject = this.core.state.get("currentProject");
            return currentProject?.id || "";
        },


        getProjects() {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects) ? projects : [];
        },


        getSeriesOptions() {
            const names = new Set();

            this.getProjects().forEach(project => {
                const series = String(project?.series || "").trim();
                if (series) {
                    names.add(series);
                }
            });

            return Array.from(names).sort((left, right) => left.localeCompare(right, undefined, { sensitivity: "base" }));
        },


        getProjectName(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        },


        getService() {
            return this.core.statisticsService;
        },


        number(value) {
            const parsed = Number(value || 0);
            return Number.isFinite(parsed) ? parsed.toLocaleString() : "0";
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


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
