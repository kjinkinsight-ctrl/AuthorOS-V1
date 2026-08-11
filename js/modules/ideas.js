/*
=========================================================
AUTHOROS
IDEAS MODULE
Milestone 03
=========================================================
*/

(function () {

    "use strict";


    window.AuthorOSIdeas = {

        name: "ideas",

        core: null,

        container: null,

        modalContainer: null,

        selectedIdeaId: null,

        isLoading: false,

        uiState: {
            search: "",
            status: "All",
            priority: "All",
            genre: "All",
            tag: "All",
            sort: "updated-desc"
        },

        statusValues: [
            "Draft",
            "Developing",
            "Ready",
            "Converted",
            "Archived"
        ],

        priorityValues: [
            "Low",
            "Medium",
            "High"
        ],


        initialize(core) {

            this.core = core;

            this.modalContainer =
                document.getElementById(
                    "modal-container"
                );

            this.synchronizeIdeasFromStorage();

        },


        render(container) {

            if (!container) {
                return;
            }

            this.container =
                container;

            if (this.isLoading) {

                container.innerHTML = this.renderLoadingState();

                return;

            }

            const ideas =
                this.getIdeas();

            const filteredIdeas =
                this.getFilteredIdeas(
                    ideas
                );

            const selectedIdea =
                this.selectedIdeaId
                    ? this.getIdea(
                        this.selectedIdeaId
                    )
                    : null;

            container.innerHTML = `

                <section class="ideas-view library-view">

                    <header class="library-header">

                        <div class="library-heading">

                            <p class="eyebrow">
                                IDEAS LIBRARY
                            </p>

                            <h1>
                                Capture Story Sparks
                            </h1>

                            <p class="library-description">
                                Collect, develop, and convert ideas into full writing projects.
                            </p>

                        </div>


                        <div class="library-actions">

                            <button
                                type="button"
                                class="button button-primary"
                                data-action="new-idea"
                            >
                                + New Idea
                            </button>

                        </div>

                    </header>


                    ${this.renderLibraryControls(ideas)}


                    <div class="library-results-bar">
                        <span class="library-count">
                            ${filteredIdeas.length}
                            ${filteredIdeas.length === 1 ? "Idea" : "Ideas"}
                        </span>
                        ${
                            this.hasActiveFilters()
                                ? `
                                    <span class="library-filter-state">
                                        Filtered from ${ideas.length} ${ideas.length === 1 ? "idea" : "ideas"}
                                    </span>
                                `
                                : ""
                        }
                    </div>


                    <div class="ideas-layout ${selectedIdea ? "with-detail" : ""}">

                        <div class="ideas-library-column">
                            ${
                                filteredIdeas.length
                                    ? this.renderIdeaGrid(filteredIdeas)
                                    : this.renderEmptyState(ideas.length > 0)
                            }
                        </div>

                        <aside class="ideas-detail-column" aria-label="Idea detail panel">
                            ${selectedIdea
                                ? this.renderIdeaDetail(selectedIdea)
                                : this.renderDetailEmptyState()}
                        </aside>

                    </div>

                </section>

            `;

            this.bindLibraryEvents(container);

        },


        renderLoadingState() {

            return `
                <section class="library-view ideas-view">
                    <div class="ideas-loading-state">
                        <h2>Loading ideas...</h2>
                        <p>Preparing your story sparks.</p>
                    </div>
                </section>
            `;

        },


        renderErrorState(message) {

            return `
                <section class="library-view ideas-view">
                    <div class="ideas-error-state">
                        <h2>Ideas are unavailable</h2>
                        <p>${this.escapeHTML(message || "Please try again.")}</p>
                        <button type="button" class="button button-secondary" data-action="retry-ideas-load">
                            Retry
                        </button>
                    </div>
                </section>
            `;

        },


        synchronizeIdeasFromStorage() {

            this.isLoading = true;

            try {

                const storedIdeas =
                    this.core.storage.loadIdeas();

                const report =
                    this.normalizeIdeaList(storedIdeas);

                this.core.state.set("ideas", report.ideas);

                if (report.changed) {
                    this.core.storage.saveIdeas(report.ideas);
                    this.core.events.emit("storage:changed");
                }

                if (
                    this.selectedIdeaId &&
                    !this.getIdea(this.selectedIdeaId)
                ) {
                    this.selectedIdeaId = null;
                }

            } catch (error) {

                console.error("Ideas storage sync failed:", error);

                this.core.notify(
                    "Unable to load ideas from storage.",
                    "error"
                );

            } finally {

                this.isLoading = false;

            }

        },


        getIdeas() {

            const ideas =
                this.core.state.get("ideas");

            return Array.isArray(ideas)
                ? ideas
                : [];

        },


        getIdea(ideaId) {

            if (
                typeof ideaId !== "string" ||
                !ideaId.trim()
            ) {
                return null;
            }

            return this.getIdeas().find(
                idea => idea.id === ideaId.trim()
            ) || null;

        },


        getVisibleStatuses() {

            return [
                "All",
                "Draft",
                "Developing",
                "Ready",
                "Converted",
                "Archived"
            ];

        },


        renderLibraryControls(ideas) {

            const genres =
                this.getUniqueValues(ideas, "genre");

            const tags =
                this.getUniqueTags(ideas);

            return `

                <div class="library-controls ideas-controls">

                    <div class="library-search">
                        <label for="ideas-search-input" class="visually-hidden">Search ideas</label>
                        <span class="library-search-icon" aria-hidden="true">⌕</span>
                        <input
                            id="ideas-search-input"
                            type="search"
                            class="library-search-input"
                            placeholder="Search ideas..."
                            autocomplete="off"
                            value="${this.escapeHTML(this.uiState.search)}"
                        />
                        ${
                            this.uiState.search
                                ? `
                                    <button
                                        type="button"
                                        class="library-search-clear"
                                        data-action="clear-ideas-search"
                                        aria-label="Clear search"
                                    >
                                        ×
                                    </button>
                                `
                                : ""
                        }
                    </div>

                    <div class="library-filter-group">
                        <label for="ideas-status-filter">Status</label>
                        <select id="ideas-status-filter" class="library-filter-select">
                            ${this.getVisibleStatuses().map(
                                value => `
                                    <option value="${this.escapeHTML(value)}" ${this.uiState.status === value ? "selected" : ""}>
                                        ${this.escapeHTML(value)}
                                    </option>
                                `
                            ).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="ideas-priority-filter">Priority</label>
                        <select id="ideas-priority-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.priority === "All" ? "selected" : ""}>All priorities</option>
                            ${this.priorityValues.map(
                                value => `
                                    <option value="${this.escapeHTML(value)}" ${this.uiState.priority === value ? "selected" : ""}>
                                        ${this.escapeHTML(value)}
                                    </option>
                                `
                            ).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="ideas-genre-filter">Genre</label>
                        <select id="ideas-genre-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.genre === "All" ? "selected" : ""}>All genres</option>
                            ${genres.map(
                                value => `
                                    <option value="${this.escapeHTML(value)}" ${this.uiState.genre === value ? "selected" : ""}>
                                        ${this.escapeHTML(value)}
                                    </option>
                                `
                            ).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="ideas-tag-filter">Tag</label>
                        <select id="ideas-tag-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.tag === "All" ? "selected" : ""}>All tags</option>
                            ${tags.map(
                                value => `
                                    <option value="${this.escapeHTML(value)}" ${this.uiState.tag === value ? "selected" : ""}>
                                        ${this.escapeHTML(value)}
                                    </option>
                                `
                            ).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="ideas-sort-filter">Sort</label>
                        <select id="ideas-sort-filter" class="library-filter-select">
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently created</option>
                            <option value="title-asc" ${this.uiState.sort === "title-asc" ? "selected" : ""}>Title A-Z</option>
                            <option value="title-desc" ${this.uiState.sort === "title-desc" ? "selected" : ""}>Title Z-A</option>
                            <option value="priority" ${this.uiState.sort === "priority" ? "selected" : ""}>Priority</option>
                        </select>
                    </div>

                    ${
                        this.hasActiveFilters()
                            ? `
                                <button
                                    type="button"
                                    class="library-clear-filters"
                                    data-action="clear-ideas-filters"
                                >
                                    Clear filters
                                </button>
                            `
                            : ""
                    }

                </div>

            `;

        },


        getUniqueValues(ideas, field) {

            const values =
                ideas
                    .map(idea => String(idea?.[field] || "").trim())
                    .filter(value => value.length > 0);

            return [...new Set(values)].sort((a, b) =>
                a.localeCompare(b, undefined, { sensitivity: "base" })
            );

        },


        getUniqueTags(ideas) {

            const tags = [];

            ideas.forEach(idea => {

                if (!Array.isArray(idea.tags)) {
                    return;
                }

                idea.tags.forEach(tag => {

                    const value =
                        String(tag || "").trim();

                    if (value) {
                        tags.push(value);
                    }

                });

            });

            return [...new Set(tags)].sort((a, b) =>
                a.localeCompare(b, undefined, { sensitivity: "base" })
            );

        },


        hasActiveFilters() {

            return Boolean(
                this.uiState.search.trim() ||
                this.uiState.status !== "All" ||
                this.uiState.priority !== "All" ||
                this.uiState.genre !== "All" ||
                this.uiState.tag !== "All" ||
                this.uiState.sort !== "updated-desc"
            );

        },


        clearFilters() {

            this.uiState = {
                search: "",
                status: "All",
                priority: "All",
                genre: "All",
                tag: "All",
                sort: "updated-desc"
            };

            this.render(this.container);

        },


        getFilteredIdeas(ideas) {

            const source =
                Array.isArray(ideas)
                    ? [...ideas]
                    : [];

            const search =
                this.uiState.search.trim().toLowerCase();

            let filtered = source;

            if (this.uiState.status === "All") {

                filtered = filtered.filter(
                    idea => idea.status !== "Archived"
                );

            }

            if (this.uiState.status !== "All") {
                filtered = filtered.filter(
                    idea => String(idea.status || "") === this.uiState.status
                );
            }

            if (this.uiState.priority !== "All") {
                filtered = filtered.filter(
                    idea => String(idea.priority || "") === this.uiState.priority
                );
            }

            if (this.uiState.genre !== "All") {
                filtered = filtered.filter(
                    idea => String(idea.genre || "") === this.uiState.genre
                );
            }

            if (this.uiState.tag !== "All") {
                filtered = filtered.filter(
                    idea =>
                        Array.isArray(idea.tags) &&
                        idea.tags.includes(this.uiState.tag)
                );
            }

            if (search) {
                filtered = filtered.filter(idea => {

                    const searchable = [
                        idea.title,
                        idea.concept,
                        idea.synopsis,
                        idea.genre,
                        Array.isArray(idea.tags) ? idea.tags.join(" ") : "",
                        idea.notes
                    ]
                        .filter(value => value !== null && value !== undefined)
                        .join(" ")
                        .toLowerCase();

                    return searchable.includes(search);

                });
            }

            return this.sortIdeas(filtered);

        },


        sortIdeas(ideas) {

            const results = [...ideas];

            const dateValue = value => {
                const time = Date.parse(value || "");
                return Number.isNaN(time)
                    ? 0
                    : time;
            };

            const priorityRank = {
                High: 3,
                Medium: 2,
                Low: 1
            };

            switch (this.uiState.sort) {

                case "created-desc":
                    return results.sort(
                        (a, b) => dateValue(b.createdAt) - dateValue(a.createdAt)
                    );

                case "title-asc":
                    return results.sort((a, b) =>
                        String(a.title || "").localeCompare(
                            String(b.title || ""),
                            undefined,
                            { sensitivity: "base" }
                        )
                    );

                case "title-desc":
                    return results.sort((a, b) =>
                        String(b.title || "").localeCompare(
                            String(a.title || ""),
                            undefined,
                            { sensitivity: "base" }
                        )
                    );

                case "priority":
                    return results.sort((a, b) => {

                        const left =
                            priorityRank[String(a.priority || "")] || 0;

                        const right =
                            priorityRank[String(b.priority || "")] || 0;

                        if (right !== left) {
                            return right - left;
                        }

                        return dateValue(b.updatedAt) - dateValue(a.updatedAt);

                    });

                case "updated-desc":
                default:
                    return results.sort(
                        (a, b) => dateValue(b.updatedAt) - dateValue(a.updatedAt)
                    );

            }

        },


        renderIdeaGrid(ideas) {

            return `
                <div class="project-grid ideas-grid">
                    ${ideas
                        .map(idea => this.renderIdeaCard(idea))
                        .join("")}
                </div>
            `;

        },


        renderIdeaCard(idea) {

            const title =
                this.escapeHTML(idea.title || "Untitled Idea");

            const previewText =
                this.escapeHTML((idea.concept || idea.synopsis || "").trim() || "No concept added yet.");

            const genre =
                this.escapeHTML(idea.genre || "Unspecified");

            const tags =
                Array.isArray(idea.tags)
                    ? idea.tags.filter(tag => typeof tag === "string" && tag.trim()).slice(0, 4)
                    : [];

            const status = this.escapeHTML(idea.status || "Draft");
            const priority = this.escapeHTML(idea.priority || "Medium");
            const updatedAt = this.escapeHTML(this.formatIdeaDate(idea.updatedAt));

            const isSelected =
                this.selectedIdeaId === idea.id;

            const convertedProject =
                idea.convertedProjectId
                    ? this.findProjectById(idea.convertedProjectId)
                    : null;

            return `
                <article class="project-card idea-card ${isSelected ? "selected" : ""}">
                    <div class="project-card-body">
                        <header class="idea-card-header">
                            <h2>${title}</h2>
                            <p class="idea-card-updated">Updated ${updatedAt}</p>
                        </header>

                        <p class="idea-card-preview">${previewText}</p>

                        <dl class="idea-card-meta">
                            <div>
                                <dt>Status</dt>
                                <dd>${status}</dd>
                            </div>
                            <div>
                                <dt>Priority</dt>
                                <dd>${priority}</dd>
                            </div>
                            <div>
                                <dt>Genre</dt>
                                <dd>${genre}</dd>
                            </div>
                        </dl>

                        ${
                            tags.length
                                ? `
                                    <ul class="idea-tag-list" aria-label="Idea tags">
                                        ${tags.map(tag => `<li>${this.escapeHTML(tag)}</li>`).join("")}
                                    </ul>
                                `
                                : ""
                        }

                        ${
                            idea.status === "Converted"
                                ? `
                                    <p class="idea-converted-label">
                                        Converted${convertedProject ? ` to ${this.escapeHTML(convertedProject.name || convertedProject.title || "project")}` : ""}
                                    </p>
                                `
                                : ""
                        }

                        <div class="idea-card-actions">
                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="open-idea"
                                data-idea-id="${this.escapeHTML(idea.id)}"
                            >
                                Open
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="edit-idea"
                                data-idea-id="${this.escapeHTML(idea.id)}"
                            >
                                Edit
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="duplicate-idea"
                                data-idea-id="${this.escapeHTML(idea.id)}"
                            >
                                Duplicate
                            </button>

                            ${
                                idea.status === "Archived"
                                    ? `
                                        <button
                                            type="button"
                                            class="button button-secondary"
                                            data-action="restore-idea"
                                            data-idea-id="${this.escapeHTML(idea.id)}"
                                        >
                                            Restore
                                        </button>
                                    `
                                    : `
                                        <button
                                            type="button"
                                            class="button button-secondary"
                                            data-action="archive-idea"
                                            data-idea-id="${this.escapeHTML(idea.id)}"
                                        >
                                            Archive
                                        </button>
                                    `
                            }

                            <button
                                type="button"
                                class="button button-danger"
                                data-action="delete-idea"
                                data-idea-id="${this.escapeHTML(idea.id)}"
                            >
                                Delete
                            </button>

                            ${
                                idea.status === "Converted" && idea.convertedProjectId
                                    ? `
                                        <button
                                            type="button"
                                            class="button button-primary"
                                            data-action="open-converted-project"
                                            data-project-id="${this.escapeHTML(idea.convertedProjectId)}"
                                        >
                                            Open Project
                                        </button>
                                    `
                                    : ""
                            }

                        </div>
                    </div>
                </article>
            `;

        },


        renderIdeaDetail(idea) {

            return `
                <article class="idea-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">IDEA DETAIL</p>
                        <h2>${this.escapeHTML(idea.title)}</h2>
                        <p class="idea-detail-subtitle">
                            ${this.escapeHTML(idea.status)} | ${this.escapeHTML(idea.priority)}
                        </p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div>
                            <dt>Genre</dt>
                            <dd>${this.escapeHTML(idea.genre || "Unspecified")}</dd>
                        </div>
                        <div>
                            <dt>Created</dt>
                            <dd>${this.escapeHTML(this.formatIdeaDate(idea.createdAt))}</dd>
                        </div>
                        <div>
                            <dt>Updated</dt>
                            <dd>${this.escapeHTML(this.formatIdeaDate(idea.updatedAt))}</dd>
                        </div>
                    </dl>

                    ${this.renderDetailTextBlock("Concept", idea.concept)}
                    ${this.renderDetailTextBlock("Synopsis", idea.synopsis)}
                    ${this.renderDetailTextBlock("Notes", idea.notes)}

                    <section class="idea-detail-tags">
                        <h3>Tags</h3>
                        ${
                            Array.isArray(idea.tags) && idea.tags.length
                                ? `
                                    <ul class="idea-tag-list">
                                        ${idea.tags.map(tag => `<li>${this.escapeHTML(tag)}</li>`).join("")}
                                    </ul>
                                `
                                : "<p>No tags added.</p>"
                        }
                    </section>

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-idea" data-idea-id="${this.escapeHTML(idea.id)}">Edit</button>
                        <button type="button" class="button button-secondary" data-action="duplicate-idea" data-idea-id="${this.escapeHTML(idea.id)}">Duplicate</button>
                        ${
                            idea.status === "Archived"
                                ? `<button type="button" class="button button-secondary" data-action="restore-idea" data-idea-id="${this.escapeHTML(idea.id)}">Restore</button>`
                                : `<button type="button" class="button button-secondary" data-action="archive-idea" data-idea-id="${this.escapeHTML(idea.id)}">Archive</button>`
                        }
                        <button type="button" class="button button-danger" data-action="delete-idea" data-idea-id="${this.escapeHTML(idea.id)}">Delete</button>
                        ${
                            idea.status === "Converted" && idea.convertedProjectId
                                ? `<button type="button" class="button button-primary" data-action="open-converted-project" data-project-id="${this.escapeHTML(idea.convertedProjectId)}">Open Project</button>`
                                : `<button type="button" class="button button-primary" data-action="convert-idea" data-idea-id="${this.escapeHTML(idea.id)}">Convert to Project</button>`
                        }
                    </div>
                </article>
            `;

        },


        renderDetailTextBlock(label, value) {

            const text =
                String(value || "").trim();

            return `
                <section class="idea-detail-section">
                    <h3>${this.escapeHTML(label)}</h3>
                    <p>${text ? this.escapeHTML(text) : "Not provided."}</p>
                </section>
            `;

        },


        renderDetailEmptyState() {

            return `
                <section class="idea-detail-empty-state">
                    <h3>Select an idea</h3>
                    <p>Open an idea card to view and manage details.</p>
                </section>
            `;

        },


        renderEmptyState(hasIdeas) {

            if (hasIdeas) {
                return `
                    <section class="library-empty-state ideas-empty-state">
                        <div class="empty-state-icon">⌕</div>
                        <h2>No ideas match your filters</h2>
                        <p>Try adjusting search, filters, or sorting.</p>
                        <button type="button" class="button button-secondary" data-action="clear-ideas-filters">Clear filters</button>
                    </section>
                `;
            }

            return `
                <section class="library-empty-state ideas-empty-state">
                    <div class="empty-state-icon">✦</div>
                    <h2>No ideas yet</h2>
                    <p>Create your first idea to start building your future stories.</p>
                    <button type="button" class="button button-primary" data-action="new-idea">Create First Idea</button>
                </section>
            `;

        },


        bindLibraryEvents(container) {

            container
                .querySelectorAll('[data-action="new-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.showIdeaFormModal();

                    });

                });

            const searchInput =
                container.querySelector("#ideas-search-input");

            if (searchInput) {

                searchInput.addEventListener("input", () => {
                    this.uiState.search = searchInput.value || "";
                    this.render(this.container);
                });

            }

            container
                .querySelector('[data-action="clear-ideas-search"]')
                ?.addEventListener("click", event => {

                    event.preventDefault();
                    this.uiState.search = "";
                    this.render(this.container);

                });

            const statusFilter = container.querySelector("#ideas-status-filter");
            const priorityFilter = container.querySelector("#ideas-priority-filter");
            const genreFilter = container.querySelector("#ideas-genre-filter");
            const tagFilter = container.querySelector("#ideas-tag-filter");
            const sortFilter = container.querySelector("#ideas-sort-filter");

            statusFilter?.addEventListener("change", () => {
                this.uiState.status = statusFilter.value || "All";
                this.render(this.container);
            });

            priorityFilter?.addEventListener("change", () => {
                this.uiState.priority = priorityFilter.value || "All";
                this.render(this.container);
            });

            genreFilter?.addEventListener("change", () => {
                this.uiState.genre = genreFilter.value || "All";
                this.render(this.container);
            });

            tagFilter?.addEventListener("change", () => {
                this.uiState.tag = tagFilter.value || "All";
                this.render(this.container);
            });

            sortFilter?.addEventListener("change", () => {
                this.uiState.sort = sortFilter.value || "updated-desc";
                this.render(this.container);
            });

            container
                .querySelectorAll('[data-action="clear-ideas-filters"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();
                        this.clearFilters();

                    });

                });

            container
                .querySelectorAll('[data-action="open-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        const ideaId =
                            button.dataset.ideaId;

                        this.openIdeaDetail(ideaId);

                    });

                });

            container
                .querySelectorAll('[data-action="edit-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.showIdeaFormModal(
                            button.dataset.ideaId
                        );

                    });

                });

            container
                .querySelectorAll('[data-action="duplicate-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.duplicateIdea(
                            button.dataset.ideaId
                        );

                    });

                });

            container
                .querySelectorAll('[data-action="archive-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.archiveIdea(
                            button.dataset.ideaId
                        );

                    });

                });

            container
                .querySelectorAll('[data-action="restore-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.restoreIdea(
                            button.dataset.ideaId
                        );

                    });

                });

            container
                .querySelectorAll('[data-action="delete-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.confirmDeleteIdea(
                            button.dataset.ideaId
                        );

                    });

                });

            container
                .querySelectorAll('[data-action="convert-idea"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.convertIdeaToProject(
                            button.dataset.ideaId
                        );

                    });

                });

            container
                .querySelectorAll('[data-action="open-converted-project"]')
                .forEach(button => {

                    button.addEventListener("click", event => {

                        event.preventDefault();

                        this.openConvertedProject(
                            button.dataset.projectId
                        );

                    });

                });

        },


        openIdeaDetail(ideaId) {

            const idea =
                this.getIdea(ideaId);

            if (!idea) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            this.selectedIdeaId = idea.id;

            this.render(this.container);

        },


        showIdeaFormModal(ideaId = null) {

            if (!this.modalContainer) {
                this.modalContainer = document.getElementById("modal-container");
            }

            if (!this.modalContainer) {
                return;
            }

            const editingIdea =
                ideaId
                    ? this.getIdea(ideaId)
                    : null;

            if (ideaId && !editingIdea) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            const isEditing = Boolean(editingIdea);

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="idea-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">IDEAS</p>
                                <h2 id="idea-modal-title">${isEditing ? "Edit Idea" : "New Idea"}</h2>
                                <p>${isEditing ? "Update your idea details." : "Capture a new story idea."}</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-idea-modal" aria-label="Close idea form">×</button>
                        </header>

                        <form id="idea-form" class="project-form" novalidate>
                            <div class="project-form-grid">

                                <label class="form-field full-width" for="idea-title-input">
                                    <span>Title *</span>
                                    <input id="idea-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(editingIdea?.title || "")}" />
                                </label>

                                <label class="form-field full-width" for="idea-concept-input">
                                    <span>Concept *</span>
                                    <textarea id="idea-concept-input" name="concept" rows="4" required>${this.escapeHTML(editingIdea?.concept || "")}</textarea>
                                </label>

                                <label class="form-field full-width" for="idea-synopsis-input">
                                    <span>Synopsis</span>
                                    <textarea id="idea-synopsis-input" name="synopsis" rows="4">${this.escapeHTML(editingIdea?.synopsis || "")}</textarea>
                                </label>

                                <label class="form-field" for="idea-genre-input">
                                    <span>Genre</span>
                                    <input id="idea-genre-input" name="genre" type="text" autocomplete="off" value="${this.escapeHTML(editingIdea?.genre || "")}" />
                                </label>

                                <label class="form-field" for="idea-tags-input">
                                    <span>Tags</span>
                                    <input id="idea-tags-input" name="tags" type="text" autocomplete="off" value="${this.escapeHTML(Array.isArray(editingIdea?.tags) ? editingIdea.tags.join(", ") : "")}" />
                                </label>

                                <label class="form-field" for="idea-status-input">
                                    <span>Status</span>
                                    <select id="idea-status-input" name="status">
                                        ${this.statusValues.map(value => `
                                            <option value="${this.escapeHTML(value)}" ${(editingIdea?.status || "Draft") === value ? "selected" : ""}>
                                                ${this.escapeHTML(value)}
                                            </option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="idea-priority-input">
                                    <span>Priority</span>
                                    <select id="idea-priority-input" name="priority">
                                        ${this.priorityValues.map(value => `
                                            <option value="${this.escapeHTML(value)}" ${(editingIdea?.priority || "Medium") === value ? "selected" : ""}>
                                                ${this.escapeHTML(value)}
                                            </option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field full-width" for="idea-notes-input">
                                    <span>Notes</span>
                                    <textarea id="idea-notes-input" name="notes" rows="4">${this.escapeHTML(editingIdea?.notes || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-idea-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${isEditing ? "Save Changes" : "Save Idea"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.bindIdeaFormEvents(editingIdea?.id || null);

        },


        bindIdeaFormEvents(editingIdeaId = null) {

            this.modalContainer
                .querySelectorAll('[data-action="close-idea-modal"]')
                .forEach(button => {

                    button.addEventListener("click", event => {
                        event.preventDefault();
                        this.closeModal();
                    });

                });

            this.bindModalBackdrop();

            const form = this.modalContainer.querySelector("#idea-form");

            form?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleIdeaFormSubmit(form, editingIdeaId);
            });

        },


        handleIdeaFormSubmit(form, editingIdeaId = null) {

            const formData = new FormData(form);

            const title = String(formData.get("title") || "").trim();
            const concept = String(formData.get("concept") || "").trim();
            const status = String(formData.get("status") || "Draft").trim();
            const priority = String(formData.get("priority") || "Medium").trim();

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("Idea title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            if (!AuthorOSValidation.required(concept)) {
                this.core.notify("Idea concept is required.", "error");
                form.querySelector('[name="concept"]')?.focus();
                return;
            }

            if (!this.isAllowedStatus(status)) {
                this.core.notify("Invalid idea status.", "error");
                return;
            }

            if (!this.isAllowedPriority(priority)) {
                this.core.notify("Invalid idea priority.", "error");
                return;
            }

            const tags =
                String(formData.get("tags") || "")
                    .split(",")
                    .map(tag => tag.trim())
                    .filter(tag => tag.length > 0);

            const now = new Date().toISOString();

            if (!editingIdeaId) {

                const created = this.createIdea({
                    id: AuthorOSHelpers.generateId("idea"),
                    title,
                    concept,
                    synopsis: String(formData.get("synopsis") || "").trim(),
                    genre: String(formData.get("genre") || "").trim(),
                    tags,
                    status,
                    priority,
                    notes: String(formData.get("notes") || "").trim(),
                    createdAt: now,
                    updatedAt: now,
                    archivedAt: status === "Archived" ? now : null,
                    convertedAt: null,
                    convertedProjectId: null
                });

                if (!created) {
                    this.core.notify("Unable to save the idea.", "error");
                    return;
                }

                this.closeModal();
                this.core.notify("Idea created.", "success");
                this.core.setStatus("Idea saved");
                this.render(this.container);

                return;

            }

            const existing = this.getIdea(editingIdeaId);

            if (!existing) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            const updated = {
                ...existing,
                title,
                concept,
                synopsis: String(formData.get("synopsis") || "").trim(),
                genre: String(formData.get("genre") || "").trim(),
                tags,
                status,
                priority,
                notes: String(formData.get("notes") || "").trim(),
                archivedAt: status === "Archived"
                    ? (existing.archivedAt || now)
                    : null,
                updatedAt: now
            };

            if (!this.saveIdea(updated)) {
                this.core.notify("Failed to update the idea.", "error");
                return;
            }

            this.selectedIdeaId = updated.id;

            this.closeModal();
            this.core.notify("Idea updated.", "success");
            this.core.setStatus("Idea updated");
            this.render(this.container);

        },


        createIdea(idea) {

            const normalized = this.normalizeIdea(idea);

            if (!normalized) {
                return false;
            }

            const ideas = this.getIdeas();
            const nextIdeas = [...ideas, normalized];

            const saved = this.core.storage.saveIdeas(nextIdeas);

            if (!saved) {
                return false;
            }

            this.core.state.set("ideas", nextIdeas);
            this.core.events.emit("storage:changed");

            this.selectedIdeaId = normalized.id;

            return true;

        },


        saveIdea(idea) {

            const normalized = this.normalizeIdea(idea);

            if (!normalized) {
                return false;
            }

            const ideas = this.getIdeas();

            const index = ideas.findIndex(item => item.id === normalized.id);

            if (index === -1) {
                return false;
            }

            const nextIdeas = [...ideas];
            nextIdeas[index] = normalized;

            const saved = this.core.storage.saveIdeas(nextIdeas);

            if (!saved) {
                return false;
            }

            this.core.state.set("ideas", nextIdeas);
            this.core.events.emit("storage:changed");

            return true;

        },


        deleteIdea(ideaId) {

            const ideas = this.getIdeas();

            const filtered = ideas.filter(idea => idea.id !== ideaId);

            if (filtered.length === ideas.length) {
                return false;
            }

            const saved = this.core.storage.saveIdeas(filtered);

            if (!saved) {
                return false;
            }

            this.core.state.set("ideas", filtered);
            this.core.events.emit("storage:changed");

            if (this.selectedIdeaId === ideaId) {
                this.selectedIdeaId = null;
            }

            return true;

        },


        duplicateIdea(ideaId) {

            const source = this.getIdea(ideaId);

            if (!source) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();

            const duplicate = {
                ...source,
                id: AuthorOSHelpers.generateId("idea"),
                title: `${source.title} - Copy`,
                status: source.status === "Converted"
                    ? "Draft"
                    : source.status,
                convertedAt: null,
                convertedProjectId: null,
                archivedAt: source.status === "Archived"
                    ? now
                    : null,
                createdAt: now,
                updatedAt: now
            };

            if (!this.createIdea(duplicate)) {
                this.core.notify("Failed to duplicate idea.", "error");
                return;
            }

            this.core.notify("Idea duplicated.", "success");
            this.render(this.container);

        },


        archiveIdea(ideaId) {

            const idea = this.getIdea(ideaId);

            if (!idea) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            if (idea.status === "Archived") {
                return;
            }

            const now = new Date().toISOString();

            if (!this.saveIdea({
                ...idea,
                status: "Archived",
                archivedAt: now,
                updatedAt: now
            })) {
                this.core.notify("Failed to archive idea.", "error");
                return;
            }

            this.core.notify("Idea archived.", "success");
            this.render(this.container);

        },


        restoreIdea(ideaId) {

            const idea = this.getIdea(ideaId);

            if (!idea) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            if (idea.status !== "Archived") {
                return;
            }

            const now = new Date().toISOString();

            if (!this.saveIdea({
                ...idea,
                status: "Draft",
                archivedAt: null,
                updatedAt: now
            })) {
                this.core.notify("Failed to restore idea.", "error");
                return;
            }

            this.core.notify("Idea restored.", "success");
            this.render(this.container);

        },


        confirmDeleteIdea(ideaId) {

            const idea = this.getIdea(ideaId);

            if (!idea) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete Idea",
                content: `
                    <p>Delete \"${this.escapeHTML(idea.title)}\"?</p>
                    <p>This action cannot be undone.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {

                    if (!this.deleteIdea(idea.id)) {
                        this.core.notify("Failed to delete idea.", "error");
                        return;
                    }

                    this.core.notify("Idea deleted.", "success");
                    this.render(this.container);

                }
            });

        },


        convertIdeaToProject(ideaId) {

            const idea = this.getIdea(ideaId);

            if (!idea) {
                this.core.notify("Idea could not be found.", "error");
                return;
            }

            if (idea.convertedProjectId) {
                this.core.notify("This idea is already converted.", "info");
                return;
            }

            const projectsModule = this.core.registry.get("projects");

            if (!projectsModule || typeof projectsModule.createProject !== "function") {
                this.core.notify("Project creation service is unavailable.", "error");
                return;
            }

            const projectsBefore = this.core.state.get("projects") || [];
            const beforeIds = new Set(projectsBefore.map(project => project.id));

            const targetWords = 0;

            try {

                projectsModule.createProject({
                    name: idea.title,
                    author: "",
                    genre: idea.genre || "",
                    type: "Novel",
                    status: "Draft",
                    series: "",
                    description: idea.synopsis || idea.concept || "",
                    targetWords
                });

            } catch (error) {

                console.error("Idea conversion failed:", error);
                this.core.notify("Failed to convert idea to project.", "error");
                return;

            }

            const projectsAfter = this.core.state.get("projects") || [];

            const createdProject = projectsAfter.find(project => !beforeIds.has(project.id)) || null;

            if (!createdProject) {
                this.core.notify("Project conversion could not be confirmed.", "error");
                return;
            }

            const now = new Date().toISOString();

            const updatedIdea = {
                ...idea,
                status: "Converted",
                convertedAt: now,
                convertedProjectId: createdProject.id,
                updatedAt: now
            };

            if (!this.saveIdea(updatedIdea)) {
                this.core.notify("Project created but idea conversion state failed to save.", "error");
                return;
            }

            this.selectedIdeaId = updatedIdea.id;

            this.core.notify("Idea converted to project.", "success");
            this.render(this.container);

        },


        openConvertedProject(projectId) {

            if (typeof projectId !== "string" || !projectId.trim()) {
                this.core.notify("Converted project ID is missing.", "error");
                return;
            }

            const projectsModule = this.core.registry.get("projects");

            if (!projectsModule || typeof projectsModule.openProject !== "function") {
                this.core.notify("Project workspace is unavailable.", "error");
                return;
            }

            const project = this.findProjectById(projectId.trim());

            if (!project) {
                this.core.notify("Converted project could not be found.", "error");
                return;
            }

            projectsModule.openProject(project.id);

        },


        findProjectById(projectId) {

            const projects = this.core.state.get("projects");

            if (!Array.isArray(projects)) {
                return null;
            }

            return projects.find(project => project.id === projectId) || null;

        },


        getIdeaSummaryCounts() {

            const ideas = this.getIdeas();

            return {
                total: ideas.length,
                draft: ideas.filter(idea => idea.status === "Draft").length,
                developing: ideas.filter(idea => idea.status === "Developing").length,
                ready: ideas.filter(idea => idea.status === "Ready").length
            };

        },


        normalizeIdeaList(ideas) {

            const source =
                Array.isArray(ideas)
                    ? ideas
                    : [];

            const normalized = [];
            const seenIds = new Set();

            source.forEach(candidate => {

                const idea = this.normalizeIdea(candidate);

                if (!idea) {
                    return;
                }

                if (seenIds.has(idea.id)) {
                    idea.id = AuthorOSHelpers.generateId("idea");
                }

                seenIds.add(idea.id);
                normalized.push(idea);

            });

            return {
                ideas: normalized,
                changed: JSON.stringify(source) !== JSON.stringify(normalized)
            };

        },


        normalizeIdea(candidate) {

            if (!candidate || typeof candidate !== "object") {
                return null;
            }

            const title = String(candidate.title || "").trim();
            const concept = String(candidate.concept || "").trim();

            if (!title || !concept) {
                return null;
            }

            const now = new Date().toISOString();

            const status = this.isAllowedStatus(candidate.status)
                ? String(candidate.status).trim()
                : "Draft";

            const priority = this.isAllowedPriority(candidate.priority)
                ? String(candidate.priority).trim()
                : "Medium";

            const normalized = {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("idea"),
                title,
                concept,
                synopsis: String(candidate.synopsis || ""),
                genre: String(candidate.genre || "").trim(),
                tags: Array.isArray(candidate.tags)
                    ? candidate.tags
                        .filter(tag => typeof tag === "string")
                        .map(tag => tag.trim())
                        .filter(tag => tag.length > 0)
                    : [],
                status,
                priority,
                notes: String(candidate.notes || ""),
                createdAt: this.normalizeDateValue(candidate.createdAt, now),
                updatedAt: this.normalizeDateValue(candidate.updatedAt, now),
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null),
                convertedAt: this.normalizeDateValue(candidate.convertedAt, null),
                convertedProjectId: typeof candidate.convertedProjectId === "string" && candidate.convertedProjectId.trim()
                    ? candidate.convertedProjectId.trim()
                    : null
            };

            if (normalized.status === "Archived" && !normalized.archivedAt) {
                normalized.archivedAt = normalized.updatedAt;
            }

            if (normalized.status === "Converted" && !normalized.convertedAt) {
                normalized.convertedAt = normalized.updatedAt;
            }

            return normalized;

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


        isAllowedStatus(value) {
            return this.statusValues.includes(String(value || "").trim());
        },


        isAllowedPriority(value) {
            return this.priorityValues.includes(String(value || "").trim());
        },


        formatIdeaDate(value) {

            if (!value) {
                return "Unavailable";
            }

            const date = new Date(value);

            if (Number.isNaN(date.getTime())) {
                return "Unavailable";
            }

            return date.toLocaleString();

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


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
