/*
=========================================================
AUTHOROS
WORLD STUDIO MODULE
Milestone 07
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSWorld = {

        name: "world",

        core: null,

        container: null,

        modalContainer: null,

        selectedEntryId: null,

        activeProjectId: null,

        uiState: {
            search: "",
            category: "All",
            status: "All",
            tag: "All",
            sort: "updated-desc"
        },

        typeValues: [
            "Location",
            "Organisation",
            "Faction",
            "Culture",
            "System",
            "Object",
            "Lore"
        ],

        typeCatalog: [
            {
                key: "location",
                label: "Location",
                icon: "◈",
                description: "Cities, regions, landmarks, realms, and places.",
                aliases: ["location"]
            },
            {
                key: "organisation",
                label: "Organisation",
                icon: "⚑",
                description: "Governments, guilds, agencies, companies, and institutions.",
                aliases: ["organisation", "organization", "guild"]
            },
            {
                key: "faction",
                label: "Faction",
                icon: "⚔",
                description: "Ideological and political groups, alliances, and rebels.",
                aliases: ["faction"]
            },
            {
                key: "culture",
                label: "Culture",
                icon: "⌘",
                description: "Societies, traditions, civilizations, and peoples.",
                aliases: ["culture"]
            },
            {
                key: "system",
                label: "System",
                icon: "◍",
                description: "Magic, technology, social, economic, and political systems.",
                aliases: ["system", "magic/system"]
            },
            {
                key: "object",
                label: "Object",
                icon: "⬢",
                description: "Artifacts, weapons, devices, vehicles, and key items.",
                aliases: ["object", "object/artifact", "artifact"]
            },
            {
                key: "lore",
                label: "Lore",
                icon: "✧",
                description: "Myths, legends, histories, records, and world knowledge.",
                aliases: ["lore"]
            },
            {
                key: "custom",
                label: "Custom",
                icon: "✎",
                description: "Anything that does not fit a predefined category.",
                aliases: ["custom"]
            }
        ],

        statusValues: [
            "Draft",
            "Developing",
            "Established",
            "Archived"
        ],

        initialize(core) {

            this.core = core;

            this.modalContainer =
                document.getElementById("modal-container");

            this.core.events.on("navigation:changed", navigation => {

                if (navigation?.route !== "world") {
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

            const hydrated = this.ensureProjectWorldShape(project);

            if (hydrated.changed) {
                this.persistProject(hydrated.project, "world-hydrate");
            }

            const currentProject = this.getProjectById(project.id) || hydrated.project;
            this.activeProjectId = currentProject.id;

            const entries = this.getWorldEntries(currentProject);

            if (
                this.selectedEntryId &&
                !entries.some(entry => entry.id === this.selectedEntryId)
            ) {
                this.selectedEntryId = null;
            }

            const filtered = this.getFilteredEntries(entries);

            const selected = this.selectedEntryId
                ? this.getWorldEntry(currentProject, this.selectedEntryId)
                : null;

            container.innerHTML = `
                <section class="world-view library-view">

                    <header class="library-header">

                        <div class="library-heading">
                            <p class="eyebrow">WORLD STUDIO</p>
                            <h1>World Library</h1>
                            <p class="library-description">
                                Build and connect the places, systems, factions, lore, and objects of your world.
                            </p>
                            <p class="world-project-context">
                                Project: ${this.escapeHTML(this.getProjectTitle(currentProject))}
                            </p>
                        </div>

                        <div class="library-actions">
                            <button type="button" class="button button-primary" data-action="new-world-entry">
                                + New World Entry
                            </button>
                        </div>

                    </header>

                    ${this.renderCategoryNavigation()}

                    ${this.renderLibraryControls(entries)}

                    <div class="library-results-bar">
                        <span class="library-count">
                            ${filtered.length}
                            ${filtered.length === 1 ? "Entry" : "Entries"}
                        </span>
                        ${
                            this.hasActiveFilters()
                                ? `
                                    <span class="library-filter-state">
                                        Filtered from ${entries.length} ${entries.length === 1 ? "entry" : "entries"}
                                    </span>
                                `
                                : ""
                        }
                    </div>

                    <div class="world-layout ${selected ? "with-detail" : ""}">

                        <div class="world-library-column">
                            ${
                                filtered.length
                                    ? this.renderWorldGrid(filtered)
                                    : this.renderEmptyState(entries.length > 0)
                            }
                        </div>

                        <aside class="world-detail-column" aria-label="World entry detail panel">
                            ${
                                selected
                                    ? this.renderWorldEntryDetail(selected, currentProject)
                                    : this.renderDetailEmptyState()
                            }
                        </aside>

                    </div>

                </section>
            `;

            this.bindEvents(container, currentProject.id);

        },


        renderMissingProjectState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">◇</div>
                    <p class="eyebrow">WORLD STUDIO</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to manage worldbuilding entries.</p>
                    <div class="manuscript-missing-actions">
                        <button type="button" class="button button-primary" data-action="open-story-library">
                            Open Story Library
                        </button>
                    </div>
                </section>
            `;

        },


        bindMissingProjectEvents(container) {

            container.querySelector('[data-action="open-story-library"]')
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


        resolveEntryTypeMeta(typeValue) {

            const raw = String(typeValue || "").trim();

            if (!raw) {
                const fallback = this.typeCatalog.find(item => item.key === "lore") || this.typeCatalog[0];
                return {
                    key: fallback.key,
                    label: fallback.label,
                    icon: fallback.icon,
                    description: fallback.description,
                    isCustom: false,
                    storedType: fallback.label,
                    filterCategory: fallback.label
                };
            }

            const normalizedRaw = raw.toLowerCase();

            const matched = this.typeCatalog.find(item =>
                item.aliases.some(alias => alias.toLowerCase() === normalizedRaw)
            );

            if (!matched || matched.key === "custom") {
                return {
                    key: "custom",
                    label: "Custom",
                    icon: "✎",
                    description: "Custom entry type",
                    isCustom: true,
                    storedType: raw,
                    filterCategory: "Custom"
                };
            }

            return {
                key: matched.key,
                label: matched.label,
                icon: matched.icon,
                description: matched.description,
                isCustom: false,
                storedType: matched.label,
                filterCategory: matched.label
            };

        },


        getTypeSelectorCatalog() {

            return this.typeCatalog.map(item => ({
                key: item.key,
                label: item.label,
                icon: item.icon,
                description: item.description
            }));

        },


        normalizeCustomFields(source) {

            const fields = Array.isArray(source)
                ? source
                : [];

            return fields
                .filter(item => item && typeof item === "object")
                .map(item => {
                    const fieldType = String(item.fieldType || "text").trim().toLowerCase();
                    const supported = ["text", "long-text", "number", "date", "checkbox", "select", "multi-select"];
                    const normalizedType = supported.includes(fieldType)
                        ? fieldType
                        : "text";

                    const options = Array.isArray(item.options)
                        ? item.options.map(option => String(option || "").trim()).filter(Boolean)
                        : String(item.options || "")
                            .split(",")
                            .map(option => option.trim())
                            .filter(Boolean);

                    const value = normalizedType === "multi-select"
                        ? Array.isArray(item.value)
                            ? item.value.map(option => String(option || "").trim()).filter(Boolean)
                            : String(item.value || "")
                                .split(",")
                                .map(option => option.trim())
                                .filter(Boolean)
                        : normalizedType === "checkbox"
                            ? Boolean(item.value)
                            : String(item.value || "");

                    return {
                        id: String(item.id || AuthorOSHelpers.generateId("world_custom_field")).trim() || AuthorOSHelpers.generateId("world_custom_field"),
                        label: String(item.label || "").trim(),
                        fieldType: normalizedType,
                        options,
                        value
                    };
                })
                .filter(field => field.label);

        },


        ensureProjectWorldShape(project) {

            const next = this.cloneData(project);

            if (!next) {
                return { project, changed: false };
            }

            let changed = false;

            if (!next.story || typeof next.story !== "object") {
                next.story = {};
                changed = true;
            }

            if (!Array.isArray(next.story.worldEntries)) {

                if (Array.isArray(next.story.world)) {
                    next.story.worldEntries = next.story.world;
                } else {
                    next.story.worldEntries = [];
                }

                changed = true;
            }

            const seen = new Set();

            next.story.worldEntries = next.story.worldEntries
                .map(candidate => {

                    const normalized = this.normalizeWorldEntry(candidate, next.id);

                    if (!normalized) {
                        changed = true;
                        return null;
                    }

                    if (JSON.stringify(candidate) !== JSON.stringify(normalized)) {
                        changed = true;
                    }

                    return normalized;

                })
                .filter(entry => Boolean(entry))
                .map(entry => {

                    let normalized = entry;

                    if (seen.has(normalized.id)) {
                        normalized = {
                            ...normalized,
                            id: AuthorOSHelpers.generateId("world")
                        };
                        changed = true;
                    }

                    seen.add(normalized.id);

                    return normalized;

                });

            const activeCount = next.story.worldEntries.filter(
                entry => entry.status !== "Archived"
            ).length;

            if (!next.statistics || typeof next.statistics !== "object") {
                next.statistics = {};
                changed = true;
            }

            if (Number(next.statistics.world || 0) !== activeCount) {
                next.statistics.world = activeCount;
                changed = true;
            }

            return {
                project: next,
                changed
            };

        },


        normalizeWorldEntry(candidate, projectId) {

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

            const title = String(candidate.title || candidate.name || "").trim() || "Untitled Entry";

            const typeMeta = this.resolveEntryTypeMeta(candidate.type);
            const type = typeMeta.storedType;

            const status = this.isAllowedStatus(candidate.status)
                ? String(candidate.status).trim()
                : "Draft";

            const tags = Array.isArray(candidate.tags)
                ? candidate.tags
                    .map(tag => String(tag || "").trim())
                    .filter(tag => tag.length > 0)
                : [];

            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);

            const references = Array.isArray(candidate.references)
                ? candidate.references
                    .map(reference => this.normalizeReference(reference, projectId, candidate.id))
                    .filter(item => Boolean(item))
                : [];

            const customFields = this.normalizeCustomFields(candidate.customFields);

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("world"),
                projectId,
                type,
                title,
                summary: String(candidate.summary || ""),
                description: String(candidate.description || ""),
                tags,
                status,
                notes: String(candidate.notes || ""),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null),

                locationType: String(candidate.locationType || ""),
                parentLocation: String(candidate.parentLocation || ""),
                appearance: String(candidate.appearance || ""),
                environment: String(candidate.environment || ""),
                geography: String(candidate.geography || ""),
                architecture: String(candidate.architecture || ""),
                residents: String(candidate.residents || ""),
                languages: String(candidate.languages || ""),
                importantPlaces: String(candidate.importantPlaces || ""),
                firstAppearance: String(candidate.firstAppearance || ""),
                importantEvents: String(candidate.importantEvents || ""),
                connectedCharacters: String(candidate.connectedCharacters || ""),
                connectedPlotThreads: String(candidate.connectedPlotThreads || ""),
                research: String(candidate.research || ""),

                organisationType: String(candidate.organisationType || candidate.organizationType || ""),
                leadershipStructure: String(candidate.leadershipStructure || ""),
                succession: String(candidate.succession || ""),
                ranks: String(candidate.ranks || ""),
                departments: String(candidate.departments || ""),
                branches: String(candidate.branches || ""),
                activities: String(candidate.activities || ""),
                headquarters: String(candidate.headquarters || ""),
                allies: String(candidate.allies || ""),
                rivals: String(candidate.rivals || ""),
                affiliations: String(candidate.affiliations || ""),
                importantCharacters: String(candidate.importantCharacters || ""),
                plotThreads: String(candidate.plotThreads || ""),

                factionType: String(candidate.factionType || ""),
                ideology: String(candidate.ideology || ""),
                goals: String(candidate.goals || ""),
                values: String(candidate.values || ""),
                motivations: String(candidate.motivations || ""),
                keyMembers: String(candidate.keyMembers || ""),
                primaryTerritory: String(candidate.primaryTerritory || ""),
                controlledLocations: String(candidate.controlledLocations || ""),
                areasOfInfluence: String(candidate.areasOfInfluence || ""),
                neutralGroups: String(candidate.neutralGroups || ""),
                currentConflicts: String(candidate.currentConflicts || ""),
                historicalConflicts: String(candidate.historicalConflicts || ""),
                majorObjectives: String(candidate.majorObjectives || ""),

                cultureType: String(candidate.cultureType || ""),
                originStory: String(candidate.originStory || ""),
                familyStructure: String(candidate.familyStructure || ""),
                genderRoles: String(candidate.genderRoles || ""),
                socialClasses: String(candidate.socialClasses || ""),
                religion: String(candidate.religion || ""),
                spiritualBeliefs: String(candidate.spiritualBeliefs || ""),
                taboos: String(candidate.taboos || ""),
                primaryLanguage: String(candidate.primaryLanguage || ""),
                writingSystem: String(candidate.writingSystem || ""),
                commonTerms: String(candidate.commonTerms || ""),
                festivals: String(candidate.festivals || ""),
                ceremonies: String(candidate.ceremonies || ""),
                clothing: String(candidate.clothing || ""),
                food: String(candidate.food || ""),
                music: String(candidate.music || ""),
                art: String(candidate.art || ""),
                origins: String(candidate.origins || ""),
                majorHistoricalEvents: String(candidate.majorHistoricalEvents || ""),
                importantFigures: String(candidate.importantFigures || ""),
                connectedLocations: String(candidate.connectedLocations || ""),
                connectedOrganisations: String(candidate.connectedOrganisations || ""),

                systemType: String(candidate.systemType || ""),
                coreRules: String(candidate.coreRules || ""),
                requirements: String(candidate.requirements || ""),
                exceptions: String(candidate.exceptions || ""),
                components: String(candidate.components || ""),
                requiredResources: String(candidate.requiredResources || ""),
                availability: String(candidate.availability || ""),
                whoCanUseIt: String(candidate.whoCanUseIt || ""),
                restrictions: String(candidate.restrictions || ""),
                training: String(candidate.training || ""),
                skillLevels: String(candidate.skillLevels || ""),
                sideEffects: String(candidate.sideEffects || ""),
                socialConsequences: String(candidate.socialConsequences || ""),
                development: String(candidate.development || ""),
                importantChanges: String(candidate.importantChanges || ""),

                objectType: String(candidate.objectType || ""),
                currentOwner: String(candidate.currentOwner || ""),
                currentLocation: String(candidate.currentLocation || ""),
                materials: String(candidate.materials || ""),
                size: String(candidate.size || ""),
                condition: String(candidate.condition || ""),
                abilities: String(candidate.abilities || ""),
                functions: String(candidate.functions || ""),
                specialProperties: String(candidate.specialProperties || ""),
                creator: String(candidate.creator || ""),
                previousOwners: String(candidate.previousOwners || ""),
                culturalSignificance: String(candidate.culturalSignificance || ""),
                politicalSignificance: String(candidate.politicalSignificance || ""),
                magicalSignificance: String(candidate.magicalSignificance || ""),
                personalSignificance: String(candidate.personalSignificance || ""),

                loreType: String(candidate.loreType || ""),
                storyContent: String(candidate.storyContent || ""),
                historicalContext: String(candidate.historicalContext || ""),
                knownEvents: String(candidate.knownEvents || ""),
                developmentOverTime: String(candidate.developmentOverTime || ""),
                whoBelievesIt: String(candidate.whoBelievesIt || ""),
                commonInterpretation: String(candidate.commonInterpretation || ""),
                alternativeInterpretation: String(candidate.alternativeInterpretation || ""),
                truthStatus: String(candidate.truthStatus || ""),
                historicalSources: String(candidate.historicalSources || ""),
                oralTradition: String(candidate.oralTradition || ""),
                writtenSources: String(candidate.writtenSources || ""),
                researchers: String(candidate.researchers || ""),

                customFields,

                region: String(candidate.region || ""),
                climate: String(candidate.climate || ""),
                population: String(candidate.population || ""),
                government: String(candidate.government || ""),
                landmarks: String(candidate.landmarks || ""),
                atmosphere: String(candidate.atmosphere || ""),

                purpose: String(candidate.purpose || ""),
                leader: String(candidate.leader || ""),
                members: String(candidate.members || ""),
                territory: String(candidate.territory || ""),
                beliefs: String(candidate.beliefs || ""),
                resources: String(candidate.resources || ""),
                enemies: String(candidate.enemies || ""),
                allies: String(candidate.allies || ""),

                customs: String(candidate.customs || ""),
                traditions: String(candidate.traditions || ""),
                language: String(candidate.language || ""),
                socialStructure: String(candidate.socialStructure || ""),
                values: String(candidate.values || ""),

                source: String(candidate.source || ""),
                rules: String(candidate.rules || ""),
                limitations: String(candidate.limitations || ""),
                costs: String(candidate.costs || ""),
                users: String(candidate.users || ""),
                effects: String(candidate.effects || ""),
                risks: String(candidate.risks || ""),

                origin: String(candidate.origin || ""),
                owner: String(candidate.owner || ""),
                material: String(candidate.material || ""),
                powers: String(candidate.powers || ""),
                history: String(candidate.history || ""),

                historicalPeriod: String(candidate.historicalPeriod || ""),
                significance: String(candidate.significance || ""),
                relatedEvents: String(candidate.relatedEvents || ""),
                knownVersions: String(candidate.knownVersions || ""),

                references
            };

        },


        normalizeReference(reference, projectId, sourceEntryId) {

            if (!reference || typeof reference !== "object") {
                return null;
            }

            const candidateTargetKind = String(
                reference.targetKind ||
                reference.targetType ||
                "world"
            ).trim().toLowerCase();

            const targetKind = candidateTargetKind === "character"
                ? "character"
                : "world";

            const targetEntryId = String(
                reference.targetEntryId ||
                reference.targetWorldEntryId ||
                reference.targetCharacterId ||
                reference.targetId ||
                ""
            ).trim();

            if (!targetEntryId) {
                return null;
            }

            const normalizedProjectId = typeof reference.projectId === "string" && reference.projectId.trim()
                ? reference.projectId.trim()
                : projectId;

            if (normalizedProjectId !== projectId) {
                return null;
            }

            return {
                sourceEntryId: String(reference.sourceEntryId || sourceEntryId || "").trim(),
                targetEntryId,
                targetKind,
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


        getWorldEntries(project) {

            if (!project?.story?.worldEntries || !Array.isArray(project.story.worldEntries)) {
                return [];
            }

            return project.story.worldEntries
                .map(entry => this.normalizeWorldEntry(entry, project.id))
                .filter(entry => Boolean(entry));

        },


        getWorldEntry(project, entryId) {

            if (!project || !entryId) {
                return null;
            }

            return this.getWorldEntries(project).find(entry => entry.id === entryId) || null;

        },


        renderCategoryNavigation() {

            const categoryValues = [
                "All",
                ...this.typeCatalog
                    .filter(item => item.key !== "custom")
                    .map(item => item.label),
                "Custom",
                "Archived"
            ];

            return `
                <nav class="world-category-nav" aria-label="World categories">
                    ${categoryValues.map(category => `
                        <button
                            type="button"
                            class="world-category-button ${this.uiState.category === category ? "active" : ""}"
                            data-action="select-world-category"
                            data-category="${this.escapeHTML(category)}"
                        >
                            ${this.escapeHTML(category)}
                        </button>
                    `).join("")}
                </nav>
            `;

        },


        renderLibraryControls(entries) {

            const tags = this.getUniqueTags(entries);

            return `
                <div class="library-controls world-controls">

                    <div class="library-search">
                        <label for="world-search-input" class="visually-hidden">Search world entries</label>
                        <span class="library-search-icon" aria-hidden="true">⌕</span>
                        <input
                            id="world-search-input"
                            type="search"
                            class="library-search-input"
                            placeholder="Search world entries..."
                            autocomplete="off"
                            value="${this.escapeHTML(this.uiState.search)}"
                        />
                        ${
                            this.uiState.search
                                ? `
                                    <button
                                        type="button"
                                        class="library-search-clear"
                                        data-action="clear-world-search"
                                        aria-label="Clear search"
                                    >
                                        ×
                                    </button>
                                `
                                : ""
                        }
                    </div>

                    <div class="library-filter-group">
                        <label for="world-status-filter">Status</label>
                        <select id="world-status-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.status === "All" ? "selected" : ""}>All</option>
                            <option value="Draft" ${this.uiState.status === "Draft" ? "selected" : ""}>Draft</option>
                            <option value="Developing" ${this.uiState.status === "Developing" ? "selected" : ""}>Developing</option>
                            <option value="Established" ${this.uiState.status === "Established" ? "selected" : ""}>Established</option>
                            <option value="Archived" ${this.uiState.status === "Archived" ? "selected" : ""}>Archived</option>
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="world-tag-filter">Tag</label>
                        <select id="world-tag-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.tag === "All" ? "selected" : ""}>All tags</option>
                            ${tags.map(tag => `
                                <option value="${this.escapeHTML(tag)}" ${this.uiState.tag === tag ? "selected" : ""}>
                                    ${this.escapeHTML(tag)}
                                </option>
                            `).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="world-sort-filter">Sort</label>
                        <select id="world-sort-filter" class="library-filter-select">
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently created</option>
                            <option value="title-asc" ${this.uiState.sort === "title-asc" ? "selected" : ""}>Title A-Z</option>
                            <option value="title-desc" ${this.uiState.sort === "title-desc" ? "selected" : ""}>Title Z-A</option>
                            <option value="type" ${this.uiState.sort === "type" ? "selected" : ""}>Type</option>
                        </select>
                    </div>

                    ${
                        this.hasActiveFilters()
                            ? `
                                <button
                                    type="button"
                                    class="library-clear-filters"
                                    data-action="clear-world-filters"
                                >
                                    Clear filters
                                </button>
                            `
                            : ""
                    }

                </div>
            `;

        },


        getUniqueTags(entries) {

            const tags = [];

            entries.forEach(entry => {

                if (!Array.isArray(entry.tags)) {
                    return;
                }

                entry.tags.forEach(tag => {
                    const value = String(tag || "").trim();
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
                this.uiState.category !== "All" ||
                this.uiState.status !== "All" ||
                this.uiState.tag !== "All" ||
                this.uiState.sort !== "updated-desc"
            );

        },


        clearFilters() {

            this.uiState = {
                search: "",
                category: "All",
                status: "All",
                tag: "All",
                sort: "updated-desc"
            };

            this.render(this.container);

        },


        getFilteredEntries(entries) {

            let filtered = Array.isArray(entries)
                ? [...entries]
                : [];

            const category = String(this.uiState.category || "All");
            const status = String(this.uiState.status || "All");

            if (category === "Archived") {
                filtered = filtered.filter(entry => entry.status === "Archived");
            } else {

                if (status === "All") {
                    filtered = filtered.filter(entry => entry.status !== "Archived");
                }

                if (category !== "All") {
                    filtered = filtered.filter(entry =>
                        this.resolveEntryTypeMeta(entry.type).filterCategory === category
                    );
                }

                if (status !== "All") {
                    filtered = filtered.filter(entry => entry.status === status);
                }

            }

            if (status === "Archived") {
                filtered = filtered.filter(entry => entry.status === "Archived");
            }

            if (this.uiState.tag !== "All") {
                filtered = filtered.filter(entry =>
                    Array.isArray(entry.tags) &&
                    entry.tags.includes(this.uiState.tag)
                );
            }

            const search = this.uiState.search.trim().toLowerCase();

            if (search) {
                filtered = filtered.filter(entry => {

                    const searchable = this.buildEntrySearchText(entry).toLowerCase();

                    return searchable.includes(search);

                });
            }

            return this.sortEntries(filtered);

        },


        sortEntries(entries) {

            const results = [...entries];

            const dateValue = value => {
                const time = Date.parse(value || "");
                return Number.isNaN(time)
                    ? 0
                    : time;
            };

            switch (this.uiState.sort) {

                case "created-desc":
                    return results.sort(
                        (left, right) => dateValue(right.createdAt) - dateValue(left.createdAt)
                    );

                case "title-asc":
                    return results.sort((left, right) =>
                        this.getEntryTitle(left).localeCompare(
                            this.getEntryTitle(right),
                            undefined,
                            { sensitivity: "base" }
                        )
                    );

                case "title-desc":
                    return results.sort((left, right) =>
                        this.getEntryTitle(right).localeCompare(
                            this.getEntryTitle(left),
                            undefined,
                            { sensitivity: "base" }
                        )
                    );

                case "type":
                    return results.sort((left, right) => {

                        const typeResult = this.resolveEntryTypeMeta(left.type).filterCategory.localeCompare(
                            this.resolveEntryTypeMeta(right.type).filterCategory,
                            undefined,
                            { sensitivity: "base" }
                        );

                        if (typeResult !== 0) {
                            return typeResult;
                        }

                        return dateValue(right.updatedAt) - dateValue(left.updatedAt);

                    });

                case "updated-desc":
                default:
                    return results.sort(
                        (left, right) => dateValue(right.updatedAt) - dateValue(left.updatedAt)
                    );

            }

        },


        buildEntrySearchText(entry) {

            const typeMeta = this.resolveEntryTypeMeta(entry?.type);

            const customFieldsText = Array.isArray(entry?.customFields)
                ? entry.customFields.map(field => {
                    const value = Array.isArray(field.value)
                        ? field.value.join(" ")
                        : String(field.value || "");
                    return `${field.label || ""} ${value}`;
                }).join(" ")
                : "";

            return [
                entry?.title,
                entry?.type,
                typeMeta.label,
                typeMeta.filterCategory,
                entry?.summary,
                entry?.description,
                entry?.notes,
                entry?.status,
                Array.isArray(entry?.tags) ? entry.tags.join(" ") : "",
                ...this.getCategoryFieldKeys().map(key => entry?.[key]),
                customFieldsText
            ]
                .filter(value => value !== null && value !== undefined)
                .join(" ");

        },


        renderWorldGrid(entries) {

            return `
                <div class="project-grid world-grid">
                    ${entries.map(entry => this.renderWorldCard(entry)).join("")}
                </div>
            `;

        },


        renderWorldCard(entry) {

            const typeMeta = this.resolveEntryTypeMeta(entry.type);
            const title = this.escapeHTML(this.getEntryTitle(entry));
            const type = this.escapeHTML(typeMeta.filterCategory);
            const status = this.escapeHTML(entry.status || "Draft");
            const summary = this.escapeHTML(String(entry.summary || "").trim() || "No summary yet.");
            const updated = this.escapeHTML(this.formatDate(entry.updatedAt));

            const tags = Array.isArray(entry.tags)
                ? entry.tags.slice(0, 5)
                : [];

            const isSelected = this.selectedEntryId === entry.id;

            return `
                <article class="project-card world-card ${isSelected ? "selected" : ""}">
                    <div class="project-card-body">

                        <header class="world-card-header">
                            <h2>${title}</h2>
                            <p class="world-card-updated">Updated ${updated}</p>
                        </header>

                        <dl class="world-card-meta">
                            <div>
                                <dt>Type</dt>
                                <dd>${this.escapeHTML(typeMeta.icon)} ${type}</dd>
                            </div>
                            <div>
                                <dt>Status</dt>
                                <dd>${status}</dd>
                            </div>
                        </dl>

                        <p class="world-card-summary">${summary}</p>

                        ${
                            tags.length
                                ? `
                                    <ul class="idea-tag-list" aria-label="World entry tags">
                                        ${tags.map(tag => `<li>${this.escapeHTML(tag)}</li>`).join("")}
                                    </ul>
                                `
                                : ""
                        }

                        <div class="idea-card-actions">
                            <button type="button" class="button button-secondary" data-action="open-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Open</button>
                            <button type="button" class="button button-secondary" data-action="edit-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Edit</button>
                            <button type="button" class="button button-secondary" data-action="duplicate-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Duplicate</button>
                            ${
                                entry.status === "Archived"
                                    ? `<button type="button" class="button button-secondary" data-action="restore-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Restore</button>`
                                    : `<button type="button" class="button button-secondary" data-action="archive-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Archive</button>`
                            }
                            <button type="button" class="button button-danger" data-action="delete-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Delete</button>
                        </div>

                    </div>
                </article>
            `;

        },


        renderEmptyState(hasEntries) {

            if (hasEntries) {
                return `
                    <section class="library-empty-state">
                        <div class="empty-state-icon">⌕</div>
                        <h2>No world entries match your filters</h2>
                        <p>Adjust search, category, status, or tags.</p>
                        <button type="button" class="button button-secondary" data-action="clear-world-filters">Clear filters</button>
                    </section>
                `;
            }

            return `
                <section class="library-empty-state">
                    <div class="empty-state-icon">◈</div>
                    <h2>No world entries yet</h2>
                    <p>Create your first world entry for this project.</p>
                    <button type="button" class="button button-primary" data-action="new-world-entry">Create First Entry</button>
                </section>
            `;

        },


        renderDetailEmptyState() {

            return `
                <section class="idea-detail-empty-state">
                    <h3>Select a world entry</h3>
                    <p>Open a world card to view and manage details.</p>
                </section>
            `;

        },


        renderWorldEntryDetail(entry, project) {

            const references = this.resolveEntryReferences(entry, project);
            const typeMeta = this.resolveEntryTypeMeta(entry.type);
            const typeFields = this.getTypeFieldDefinitions(typeMeta.storedType);

            return `
                <article class="idea-detail-card world-detail-card">

                    <header class="idea-detail-header">
                        <p class="eyebrow">WORLD ENTRY</p>
                        <h2>${this.escapeHTML(this.getEntryTitle(entry))}</h2>
                        <p class="idea-detail-subtitle">
                            ${this.escapeHTML(typeMeta.icon)} ${this.escapeHTML(typeMeta.filterCategory)} | ${this.escapeHTML(entry.status || "Draft")}
                        </p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div>
                            <dt>Created</dt>
                            <dd>${this.escapeHTML(this.formatDate(entry.createdAt))}</dd>
                        </div>
                        <div>
                            <dt>Updated</dt>
                            <dd>${this.escapeHTML(this.formatDate(entry.updatedAt))}</dd>
                        </div>
                    </dl>

                    <section class="idea-detail-section">
                        <h3>Core</h3>
                        <p><strong>Title:</strong> ${this.escapeHTML(entry.title || "Not provided")}</p>
                        <p><strong>Type:</strong> ${this.escapeHTML(typeMeta.filterCategory)}</p>
                        <p><strong>Status:</strong> ${this.escapeHTML(entry.status || "Draft")}</p>
                        <p><strong>Tags:</strong> ${
                            Array.isArray(entry.tags) && entry.tags.length
                                ? this.escapeHTML(entry.tags.join(", "))
                                : "No tags"
                        }</p>
                    </section>

                    ${this.renderDetailTextBlock("Summary", entry.summary)}
                    ${this.renderDetailTextBlock("Description", entry.description)}

                    ${
                        typeFields.length
                            ? `
                                <section class="idea-detail-section">
                                    <h3>${this.escapeHTML(typeMeta.filterCategory)} Details</h3>
                                    ${typeFields.map(field => `
                                        <p>
                                            <strong>${this.escapeHTML(field.label)}:</strong>
                                            ${this.escapeHTML(String(entry[field.key] || "Not provided"))}
                                        </p>
                                    `).join("")}
                                </section>
                            `
                            : ""
                    }

                    ${this.renderCustomFieldsDetail(entry)}

                    ${this.renderDetailTextBlock("Notes", entry.notes)}

                    <section class="idea-detail-section">
                        <h3>Relationships</h3>
                        ${
                            references.length
                                ? `
                                    <ul class="world-reference-list">
                                        ${references.map((item, index) => `
                                            <li>
                                                <div class="world-reference-item-main">
                                                    <strong>${this.escapeHTML(item.relationshipType || "Related")}</strong>
                                                    <p>${this.escapeHTML(item.targetLabel)}</p>
                                                    <p>${this.escapeHTML(item.description || "No description.")}</p>
                                                </div>
                                                <div class="world-reference-item-actions">
                                                    <button type="button" class="button button-secondary" data-action="edit-world-reference" data-entry-id="${this.escapeHTML(entry.id)}" data-reference-index="${index}">Edit</button>
                                                    <button type="button" class="button button-danger" data-action="remove-world-reference" data-entry-id="${this.escapeHTML(entry.id)}" data-reference-index="${index}">Remove</button>
                                                </div>
                                            </li>
                                        `).join("")}
                                    </ul>
                                `
                                : "<p>No references added.</p>"
                        }
                        <button type="button" class="button button-secondary" data-action="add-world-reference" data-entry-id="${this.escapeHTML(entry.id)}">Add Reference</button>
                    </section>

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Edit</button>
                        <button type="button" class="button button-secondary" data-action="duplicate-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Duplicate</button>
                        ${
                            entry.status === "Archived"
                                ? `<button type="button" class="button button-secondary" data-action="restore-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Restore</button>`
                                : `<button type="button" class="button button-secondary" data-action="archive-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Archive</button>`
                        }
                        <button type="button" class="button button-danger" data-action="delete-world-entry" data-entry-id="${this.escapeHTML(entry.id)}">Delete</button>
                    </div>

                </article>
            `;

        },


        renderCustomFieldsDetail(entry) {

            const customFields = this.normalizeCustomFields(entry?.customFields);

            if (!customFields.length) {
                return "";
            }

            return `
                <section class="idea-detail-section">
                    <h3>Custom Fields</h3>
                    ${customFields.map(field => {
                        const value = Array.isArray(field.value)
                            ? field.value.join(", ")
                            : field.fieldType === "checkbox"
                                ? (field.value ? "Yes" : "No")
                                : String(field.value || "");

                        return `
                            <p>
                                <strong>${this.escapeHTML(field.label)}:</strong>
                                ${this.escapeHTML(value || "Not provided")}
                            </p>
                        `;
                    }).join("")}
                </section>
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


        resolveEntryReferences(entry, project) {

            const worldEntries = this.getWorldEntries(project);
            const worldLookup = new Map(worldEntries.map(item => [item.id, item]));

            const characters = Array.isArray(project?.story?.characters)
                ? project.story.characters
                : [];

            const characterLookup = new Map(
                characters
                    .filter(item => item && typeof item === "object")
                    .map(item => [String(item.id || "").trim(), item])
            );

            const source = Array.isArray(entry.references)
                ? entry.references
                : [];

            return source.map(reference => {

                const targetId = String(reference.targetEntryId || "").trim();
                const targetKind = String(reference.targetKind || "world").trim().toLowerCase();

                let targetLabel = "Missing reference target";

                if (targetKind === "character") {

                    const targetCharacter = characterLookup.get(targetId);

                    targetLabel = targetCharacter
                        ? `Character: ${String(targetCharacter.displayName || targetCharacter.name || "Unnamed Character")}`
                        : "Missing character reference";

                } else {

                    const targetEntry = worldLookup.get(targetId);

                    targetLabel = targetEntry
                        ? `World: ${this.getEntryTitle(targetEntry)}`
                        : "Missing world reference";

                }

                return {
                    ...reference,
                    targetLabel
                };

            });

        },


        bindEvents(container, projectId) {

            container.querySelectorAll('[data-action="new-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showWorldTypeSelectorModal(projectId);
                });
            });

            container.querySelectorAll('[data-action="select-world-category"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.uiState.category = String(button.dataset.category || "All");

                    if (this.uiState.category === "Archived") {
                        this.uiState.status = "Archived";
                    }

                    this.render(this.container);
                });
            });

            const searchInput = container.querySelector("#world-search-input");

            if (searchInput) {
                searchInput.addEventListener("input", () => {
                    this.uiState.search = searchInput.value || "";
                    this.render(this.container);
                });
            }

            container.querySelector('[data-action="clear-world-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.search = "";
                this.render(this.container);
            });

            const statusFilter = container.querySelector("#world-status-filter");
            const tagFilter = container.querySelector("#world-tag-filter");
            const sortFilter = container.querySelector("#world-sort-filter");

            statusFilter?.addEventListener("change", () => {
                this.uiState.status = statusFilter.value || "All";
                if (this.uiState.status !== "Archived" && this.uiState.category === "Archived") {
                    this.uiState.category = "All";
                }
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

            container.querySelectorAll('[data-action="clear-world-filters"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.clearFilters();
                });
            });

            container.querySelectorAll('[data-action="open-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openWorldEntry(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="edit-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showWorldEntryFormModal(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="duplicate-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.duplicateWorldEntry(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="archive-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.archiveWorldEntry(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="restore-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.restoreWorldEntry(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="delete-world-entry"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.confirmDeleteWorldEntry(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="add-world-reference"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showReferenceModal(projectId, button.dataset.entryId);
                });
            });

            container.querySelectorAll('[data-action="edit-world-reference"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const index = Number(button.dataset.referenceIndex);

                    this.showReferenceModal(
                        projectId,
                        button.dataset.entryId,
                        Number.isFinite(index) ? index : -1
                    );

                });
            });

            container.querySelectorAll('[data-action="remove-world-reference"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const index = Number(button.dataset.referenceIndex);

                    this.removeReference(
                        projectId,
                        button.dataset.entryId,
                        Number.isFinite(index) ? index : -1
                    );

                });
            });

        },


        openWorldEntry(projectId, entryId) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const entry = this.getWorldEntry(project, entryId);

            if (!entry) {
                this.core.notify("World entry could not be found.", "error");
                return;
            }

            this.selectedEntryId = entry.id;
            this.render(this.container);

        },


        showWorldTypeSelectorModal(projectId) {

            if (!this.modalContainer) {
                this.modalContainer = document.getElementById("modal-container");
            }

            if (!this.modalContainer) {
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const selectorCards = this.getTypeSelectorCatalog();

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal world-entry-modal" role="dialog" aria-modal="true" aria-labelledby="world-type-selector-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">WORLD STUDIO</p>
                                <h2 id="world-type-selector-modal-title">Choose Entry Type</h2>
                                <p>Select a template to start your world entry.</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-world-type-modal" aria-label="Close world type selector">×</button>
                        </header>

                        <div class="world-type-selector-grid">
                            ${selectorCards.map(item => `
                                <button
                                    type="button"
                                    class="world-type-selector-card"
                                    data-action="select-world-template-type"
                                    data-type="${this.escapeHTML(item.label)}"
                                >
                                    <span class="world-type-selector-icon" aria-hidden="true">${this.escapeHTML(item.icon)}</span>
                                    <span class="world-type-selector-title">${this.escapeHTML(item.label)}</span>
                                    <span class="world-type-selector-description">${this.escapeHTML(item.description)}</span>
                                </button>
                            `).join("")}
                        </div>

                        <footer class="project-modal-footer">
                            <button type="button" class="button button-secondary" data-action="close-world-type-modal">Cancel</button>
                        </footer>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-world-type-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.modalContainer.querySelectorAll('[data-action="select-world-template-type"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    const selectedType = String(button.dataset.type || "").trim() || "Lore";
                    this.showWorldEntryFormModal(projectId, null, selectedType);
                });
            });

            this.bindModalBackdrop();

        },


        showWorldEntryFormModal(projectId, entryId = null, preferredType = null) {

            if (!this.modalContainer) {
                this.modalContainer = document.getElementById("modal-container");
            }

            if (!this.modalContainer) {
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const editingEntry = entryId
                ? this.getWorldEntry(project, entryId)
                : null;

            if (entryId && !editingEntry) {
                this.core.notify("World entry could not be found.", "error");
                return;
            }

            const isEditing = Boolean(editingEntry);
            const initialTypeMeta = this.resolveEntryTypeMeta(
                isEditing
                    ? editingEntry?.type
                    : preferredType || "Location"
            );
            const hasCustomType = initialTypeMeta.isCustom;
            const selectedTypeValue = hasCustomType
                ? "__custom__"
                : initialTypeMeta.storedType;
            const customTypeValue = hasCustomType ? initialTypeMeta.storedType : "";

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal world-entry-modal" role="dialog" aria-modal="true" aria-labelledby="world-entry-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">WORLD STUDIO</p>
                                <h2 id="world-entry-modal-title">${isEditing ? "Edit World Entry" : "New World Entry"}</h2>
                                <p>${isEditing ? "Update world details." : "Create a new world entry."}</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-world-entry-modal" aria-label="Close world entry form">×</button>
                        </header>

                        <form id="world-entry-form" class="project-form" novalidate>
                            <div class="project-form-grid">

                                <label class="form-field form-field-wide" for="world-title-input">
                                    <span>Title *</span>
                                    <input id="world-title-input" name="title" type="text" required autocomplete="off" value="${this.escapeHTML(editingEntry?.title || "")}" />
                                </label>

                                <label class="form-field" for="world-type-input">
                                    <span>Type *</span>
                                    <select id="world-type-input" name="type" required>
                                        ${this.typeValues.map(type => `
                                            <option value="${this.escapeHTML(type)}" ${type === selectedTypeValue ? "selected" : ""}>
                                                ${this.escapeHTML(type)}
                                            </option>
                                        `).join("")}
                                        <option value="__custom__" ${selectedTypeValue === "__custom__" ? "selected" : ""}>Custom...</option>
                                    </select>
                                </label>

                                <label class="form-field world-custom-type-field ${selectedTypeValue === "__custom__" ? "" : "is-hidden"}" for="world-custom-type-input">
                                    <span>Custom Type *</span>
                                    <input id="world-custom-type-input" name="customType" type="text" autocomplete="off" value="${this.escapeHTML(customTypeValue)}" placeholder="Enter a custom type" />
                                </label>

                                <label class="form-field" for="world-status-input">
                                    <span>Status</span>
                                    <select id="world-status-input" name="status">
                                        ${this.statusValues.map(value => `
                                            <option value="${this.escapeHTML(value)}" ${(editingEntry?.status || "Draft") === value ? "selected" : ""}>
                                                ${this.escapeHTML(value)}
                                            </option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="world-tags-input">
                                    <span>Tags</span>
                                    <input id="world-tags-input" name="tags" type="text" autocomplete="off" value="${this.escapeHTML(Array.isArray(editingEntry?.tags) ? editingEntry.tags.join(", ") : "")}" />
                                </label>

                                <label class="form-field form-field-wide" for="world-summary-input">
                                    <span>Summary</span>
                                    <textarea id="world-summary-input" name="summary" rows="3">${this.escapeHTML(editingEntry?.summary || "")}</textarea>
                                </label>

                                <label class="form-field form-field-wide" for="world-description-input">
                                    <span>Description</span>
                                    <textarea id="world-description-input" name="description" rows="4">${this.escapeHTML(editingEntry?.description || "")}</textarea>
                                </label>

                                ${this.renderTypeSpecificFormFields(selectedTypeValue, editingEntry)}

                                <section class="form-field form-field-wide world-custom-field-builder ${selectedTypeValue === "__custom__" ? "" : "is-hidden"}">
                                    <h3 class="world-type-group-title">Custom Fields</h3>
                                    <p class="world-custom-fields-description">Add fields for values unique to this custom type.</p>
                                    <div class="world-custom-field-list">
                                        ${this.renderCustomFieldRows(editingEntry?.customFields)}
                                    </div>
                                    <button type="button" class="button button-secondary" data-action="add-world-custom-field">+ Add Custom Field</button>
                                </section>

                                <label class="form-field form-field-wide" for="world-notes-input">
                                    <span>Notes</span>
                                    <textarea id="world-notes-input" name="notes" rows="4">${this.escapeHTML(editingEntry?.notes || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-world-entry-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${isEditing ? "Save Changes" : "Save Entry"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-world-entry-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            const form = this.modalContainer.querySelector("#world-entry-form");
            const typeInput = this.modalContainer.querySelector("#world-type-input");
            let previousType = selectedTypeValue;

            typeInput?.addEventListener("change", () => {
                const nextType = typeInput.value || "";

                if (nextType !== previousType && this.hasTemplateDraftData(form, previousType)) {
                    const confirmed = window.confirm("Switch template type? Type-specific fields for the current template will be cleared.");

                    if (!confirmed) {
                        typeInput.value = previousType;
                        return;
                    }
                }

                previousType = nextType;
                this.toggleTypeSpecificFieldVisibility(nextType);
            });

            form?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleWorldEntryFormSubmit(projectId, editingEntry?.id || null, event.currentTarget);
            });

            this.toggleTypeSpecificFieldVisibility(selectedTypeValue);
            this.bindCustomFieldBuilderEvents();

            this.modalContainer.querySelector("#world-title-input")?.focus();

        },


        renderTypeSpecificFormFields(typeValue, entry) {

            const groups = this.typeCatalog
                .filter(item => item.key !== "custom")
                .map(item => item.label);

            return groups.map(group => {

                const sections = this.getTypeTemplateSections(group);

                const groupKey =
                    String(group)
                        .toLowerCase()
                        .replaceAll("/", "-")
                        .replaceAll(/\s+/g, "-");

                return `
                    <section class="form-field form-field-wide world-type-group" data-type-group="${this.escapeHTML(group)}">
                        <h3 class="world-type-group-title">${this.escapeHTML(group)} Fields</h3>
                        <div class="world-type-sections-grid">
                            ${sections.map(section => `
                                <section class="world-template-section">
                                    <h4 class="world-template-section-title">${this.escapeHTML(section.title)}</h4>
                                    <div class="world-type-group-grid">
                                        ${section.fields.map(field => this.renderTemplateFieldControl(groupKey, field, entry)).join("")}
                                    </div>
                                </section>
                            `).join("")}
                        </div>
                    </section>
                `;

            }).join("");

        },


        renderTemplateFieldControl(groupKey, field, entry) {

            const inputId = `world-field-${groupKey}-${field.key}`;
            const value = String(entry?.[field.key] || "");
            const control = String(field.control || "textarea").toLowerCase();

            if (control === "input") {
                return `
                    <label class="form-field form-field-wide" for="${this.escapeHTML(inputId)}">
                        <span>${this.escapeHTML(field.label)}</span>
                        <input id="${this.escapeHTML(inputId)}" name="${this.escapeHTML(field.key)}" type="text" autocomplete="off" value="${this.escapeHTML(value)}" />
                    </label>
                `;
            }

            return `
                <label class="form-field form-field-wide" for="${this.escapeHTML(inputId)}">
                    <span>${this.escapeHTML(field.label)}</span>
                    <textarea id="${this.escapeHTML(inputId)}" name="${this.escapeHTML(field.key)}" rows="2">${this.escapeHTML(value)}</textarea>
                </label>
            `;

        },


        toggleTypeSpecificFieldVisibility(typeValue) {

            const normalizedType = String(typeValue || "").trim();

            const customTypeField = this.modalContainer?.querySelector(".world-custom-type-field");

            if (customTypeField) {
                customTypeField.classList.toggle("is-hidden", normalizedType !== "__custom__");
            }

            this.modalContainer
                ?.querySelectorAll(".world-type-group")
                .forEach(group => {

                    const groupType = String(group.dataset.typeGroup || "");

                    if (normalizedType === "__custom__") {
                        group.classList.add("is-hidden");
                    } else if (groupType === normalizedType) {
                        group.classList.remove("is-hidden");
                    } else {
                        group.classList.add("is-hidden");
                    }

                });

            const customBuilder = this.modalContainer?.querySelector(".world-custom-field-builder");

            if (customBuilder) {
                customBuilder.classList.toggle("is-hidden", normalizedType !== "__custom__");
            }

        },


        renderCustomFieldRows(source) {

            const fields = this.normalizeCustomFields(source);

            if (!fields.length) {
                return this.renderCustomFieldRow();
            }

            return fields.map(field => this.renderCustomFieldRow(field)).join("");

        },


        renderCustomFieldRow(field = null) {

            const safeField = field && typeof field === "object"
                ? field
                : {
                    id: AuthorOSHelpers.generateId("world_custom_field"),
                    label: "",
                    fieldType: "text",
                    options: [],
                    value: ""
                };

            const typeValue = String(safeField.fieldType || "text").trim() || "text";
            const value = Array.isArray(safeField.value)
                ? safeField.value.join(", ")
                : typeValue === "checkbox"
                    ? (safeField.value ? "true" : "false")
                    : String(safeField.value || "");

            return `
                <div class="world-custom-field-row" data-field-id="${this.escapeHTML(safeField.id)}">
                    <label class="form-field" for="world-custom-label-${this.escapeHTML(safeField.id)}">
                        <span>Label</span>
                        <input id="world-custom-label-${this.escapeHTML(safeField.id)}" class="world-custom-label" type="text" value="${this.escapeHTML(safeField.label || "")}" />
                    </label>

                    <label class="form-field" for="world-custom-type-${this.escapeHTML(safeField.id)}">
                        <span>Field Type</span>
                        <select id="world-custom-type-${this.escapeHTML(safeField.id)}" class="world-custom-field-type">
                            ${["text", "long-text", "number", "date", "checkbox", "select", "multi-select"].map(option => `
                                <option value="${this.escapeHTML(option)}" ${option === typeValue ? "selected" : ""}>${this.escapeHTML(option)}</option>
                            `).join("")}
                        </select>
                    </label>

                    <label class="form-field" for="world-custom-options-${this.escapeHTML(safeField.id)}">
                        <span>Options (comma separated)</span>
                        <input id="world-custom-options-${this.escapeHTML(safeField.id)}" class="world-custom-options" type="text" value="${this.escapeHTML(Array.isArray(safeField.options) ? safeField.options.join(", ") : "")}" />
                    </label>

                    <label class="form-field form-field-wide" for="world-custom-value-${this.escapeHTML(safeField.id)}">
                        <span>Value</span>
                        <input id="world-custom-value-${this.escapeHTML(safeField.id)}" class="world-custom-value" type="text" value="${this.escapeHTML(value)}" />
                    </label>

                    <div class="world-custom-row-actions">
                        <button type="button" class="button button-secondary" data-action="move-world-custom-field-up">Up</button>
                        <button type="button" class="button button-secondary" data-action="move-world-custom-field-down">Down</button>
                        <button type="button" class="button button-danger" data-action="remove-world-custom-field">Remove</button>
                    </div>
                </div>
            `;

        },


        bindCustomFieldBuilderEvents() {

            const root = this.modalContainer;
            const modal = root?.querySelector(".world-entry-modal");

            if (!root || !modal) {
                return;
            }

            root.querySelectorAll('[data-action="add-world-custom-field"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    const list = root.querySelector(".world-custom-field-list");

                    if (!list) {
                        return;
                    }

                    list.insertAdjacentHTML("beforeend", this.renderCustomFieldRow());
                });
            });

            modal.addEventListener("click", event => {
                const trigger = event.target?.closest("[data-action]");

                if (!trigger) {
                    return;
                }

                const action = String(trigger.dataset.action || "");

                if (
                    action !== "remove-world-custom-field" &&
                    action !== "move-world-custom-field-up" &&
                    action !== "move-world-custom-field-down"
                ) {
                    return;
                }

                const row = trigger.closest(".world-custom-field-row");
                const list = modal.querySelector(".world-custom-field-list");

                if (!row || !list) {
                    return;
                }

                event.preventDefault();

                if (action === "remove-world-custom-field") {
                    row.remove();
                    if (!list.querySelector(".world-custom-field-row")) {
                        list.insertAdjacentHTML("beforeend", this.renderCustomFieldRow());
                    }
                    return;
                }

                if (action === "move-world-custom-field-up") {
                    const previous = row.previousElementSibling;
                    if (previous) {
                        list.insertBefore(row, previous);
                    }
                    return;
                }

                const next = row.nextElementSibling;
                if (next) {
                    list.insertBefore(next, row);
                }
            });

        },


        hasTemplateDraftData(form, selectedType) {

            if (!form) {
                return false;
            }

            const typeValue = String(selectedType || "").trim();

            if (typeValue === "__custom__") {
                const customType = String(form.querySelector('[name="customType"]')?.value || "").trim();
                if (customType) {
                    return true;
                }

                const hasCustomFieldData = Array.from(form.querySelectorAll(".world-custom-field-row")).some(row => {
                    const label = String(row.querySelector(".world-custom-label")?.value || "").trim();
                    const options = String(row.querySelector(".world-custom-options")?.value || "").trim();
                    const value = String(row.querySelector(".world-custom-value")?.value || "").trim();
                    return Boolean(label || options || value);
                });

                return hasCustomFieldData;
            }

            const fields = this.getTypeFieldDefinitions(typeValue);

            return fields.some(field => String(form.querySelector(`[name="${field.key}"]`)?.value || "").trim());

        },


        collectCustomFieldsFromForm(form) {

            if (!form) {
                return [];
            }

            return this.normalizeCustomFields(
                Array.from(form.querySelectorAll(".world-custom-field-row")).map(row => {
                    const fieldType = String(row.querySelector(".world-custom-field-type")?.value || "text").trim().toLowerCase();
                    const rawValue = String(row.querySelector(".world-custom-value")?.value || "").trim();

                    let value = rawValue;

                    if (fieldType === "checkbox") {
                        value = ["true", "yes", "1", "checked"].includes(rawValue.toLowerCase());
                    } else if (fieldType === "multi-select") {
                        value = rawValue
                            .split(",")
                            .map(item => item.trim())
                            .filter(Boolean);
                    }

                    return {
                        id: String(row.dataset.fieldId || AuthorOSHelpers.generateId("world_custom_field")).trim(),
                        label: String(row.querySelector(".world-custom-label")?.value || "").trim(),
                        fieldType,
                        options: String(row.querySelector(".world-custom-options")?.value || "")
                            .split(",")
                            .map(item => item.trim())
                            .filter(Boolean),
                        value
                    };
                })
            );

        },


        handleWorldEntryFormSubmit(projectId, editingEntryId, form) {

            const formData = new FormData(form);

            const title = String(formData.get("title") || "").trim();
            const selectedType = String(formData.get("type") || "").trim();
            const customType = String(formData.get("customType") || "").trim();
            const type = selectedType === "__custom__"
                ? customType
                : selectedType;
            const status = String(formData.get("status") || "Draft").trim() || "Draft";

            if (!AuthorOSValidation.required(title)) {
                this.core.notify("World entry title is required.", "error");
                form.querySelector('[name="title"]')?.focus();
                return;
            }

            if (!AuthorOSValidation.required(type)) {
                this.core.notify(
                    selectedType === "__custom__"
                        ? "Custom world entry type is required."
                        : "World entry type is required.",
                    "error"
                );
                form.querySelector(selectedType === "__custom__" ? '[name="customType"]' : '[name="type"]')?.focus();
                return;
            }

            if (!this.isAllowedStatus(status)) {
                this.core.notify("Invalid world entry status.", "error");
                return;
            }

            const tags = String(formData.get("tags") || "")
                .split(",")
                .map(tag => tag.trim())
                .filter(tag => tag.length > 0);

            const selectedTypeFields = this.getTypeFieldDefinitions(type);
            const selectedFieldKeys = new Set(selectedTypeFields.map(field => field.key));

            const now = new Date().toISOString();

            const sharedFields = {
                title,
                type,
                status,
                summary: String(formData.get("summary") || ""),
                description: String(formData.get("description") || ""),
                tags,
                notes: String(formData.get("notes") || ""),
                archivedAt: status === "Archived" ? now : null,
                updatedAt: now
            };

            this.getCategoryFieldKeys().forEach(key => {
                sharedFields[key] = selectedFieldKeys.has(key)
                    ? String(formData.get(key) || "")
                    : "";
            });

            sharedFields.customFields = selectedType === "__custom__"
                ? this.collectCustomFieldsFromForm(form)
                : [];

            if (!editingEntryId) {

                const created = this.createWorldEntry(projectId, {
                    id: AuthorOSHelpers.generateId("world"),
                    projectId,
                    ...sharedFields,
                    references: [],
                    createdAt: now
                });

                if (!created) {
                    this.core.notify("Unable to save world entry.", "error");
                    return;
                }

                this.closeModal();
                this.core.notify("World entry created.", "success");
                this.render(this.container);

                return;

            }

            const updated = this.updateWorldEntry(projectId, editingEntryId, sharedFields);

            if (!updated) {
                this.core.notify("Failed to update world entry.", "error");
                return;
            }

            this.selectedEntryId = editingEntryId;
            this.closeModal();
            this.core.notify("World entry updated.", "success");
            this.render(this.container);

        },


        createWorldEntry(projectId, entryPayload) {

            return this.updateProjectWorldEntries(
                projectId,
                entries => {

                    const normalized = this.normalizeWorldEntry(entryPayload, projectId);

                    if (!normalized) {
                        return null;
                    }

                    return [...entries, normalized];

                },
                "world-create",
                nextEntries => {
                    this.selectedEntryId = nextEntries[nextEntries.length - 1]?.id || null;
                }
            );

        },


        updateWorldEntry(projectId, entryId, updates) {

            return this.updateProjectWorldEntries(
                projectId,
                entries => {

                    const index = entries.findIndex(entry => entry.id === entryId);

                    if (index === -1) {
                        this.core.notify("World entry could not be found.", "error");
                        return null;
                    }

                    const existing = entries[index];
                    const nextEntry = this.normalizeWorldEntry(
                        {
                            ...existing,
                            ...updates,
                            id: existing.id,
                            projectId: existing.projectId,
                            createdAt: existing.createdAt,
                            references: Array.isArray(existing.references)
                                ? existing.references
                                : []
                        },
                        projectId
                    );

                    if (!nextEntry) {
                        return null;
                    }

                    const next = [...entries];
                    next[index] = nextEntry;
                    return next;

                },
                "world-update"
            );

        },


        deleteWorldEntry(projectId, entryId) {

            return this.updateProjectWorldEntries(
                projectId,
                entries => {

                    const exists = entries.some(entry => entry.id === entryId);

                    if (!exists) {
                        return null;
                    }

                    const filtered = entries
                        .filter(entry => entry.id !== entryId)
                        .map(entry => ({
                            ...entry,
                            references: Array.isArray(entry.references)
                                ? entry.references.filter(reference => {
                                    const targetId = String(reference.targetEntryId || "").trim();
                                    const targetKind = String(reference.targetKind || "world").trim().toLowerCase();

                                    if (targetKind !== "world") {
                                        return true;
                                    }

                                    return targetId !== entryId;
                                })
                                : []
                        }));

                    return filtered;

                },
                "world-delete",
                nextEntries => {

                    if (this.selectedEntryId === entryId) {
                        this.selectedEntryId = nextEntries[0]?.id || null;
                    }

                }
            );

        },


        duplicateWorldEntry(projectId, entryId) {

            const project = this.getProjectById(projectId);
            const source = this.getWorldEntry(project, entryId);

            if (!source) {
                this.core.notify("World entry could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();

            const duplicate = {
                ...source,
                id: AuthorOSHelpers.generateId("world"),
                title: `${source.title} - Copy`,
                status: source.status === "Archived" ? "Draft" : source.status,
                archivedAt: null,
                references: Array.isArray(source.references)
                    ? source.references.map(item => ({
                        ...item,
                        sourceEntryId: ""
                    }))
                    : [],
                createdAt: now,
                updatedAt: now
            };

            if (!this.createWorldEntry(projectId, duplicate)) {
                this.core.notify("Failed to duplicate world entry.", "error");
                return;
            }

            this.core.notify("World entry duplicated.", "success");
            this.render(this.container);

        },


        archiveWorldEntry(projectId, entryId) {

            const now = new Date().toISOString();

            const saved = this.updateWorldEntry(projectId, entryId, {
                status: "Archived",
                archivedAt: now,
                updatedAt: now
            });

            if (!saved) {
                this.core.notify("Failed to archive world entry.", "error");
                return;
            }

            this.core.notify("World entry archived.", "success");
            this.render(this.container);

        },


        restoreWorldEntry(projectId, entryId) {

            const now = new Date().toISOString();

            const saved = this.updateWorldEntry(projectId, entryId, {
                status: "Draft",
                archivedAt: null,
                updatedAt: now
            });

            if (!saved) {
                this.core.notify("Failed to restore world entry.", "error");
                return;
            }

            this.core.notify("World entry restored.", "success");
            this.render(this.container);

        },


        confirmDeleteWorldEntry(projectId, entryId) {

            const project = this.getProjectById(projectId);
            const entry = this.getWorldEntry(project, entryId);

            if (!entry) {
                this.core.notify("World entry could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete World Entry",
                content: `
                    <p>Delete \"${this.escapeHTML(this.getEntryTitle(entry))}\"?</p>
                    <p>This action permanently removes the world entry.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {

                    if (!this.deleteWorldEntry(projectId, entry.id)) {
                        this.core.notify("Failed to delete world entry.", "error");
                        return;
                    }

                    this.core.notify("World entry deleted.", "success");
                    this.render(this.container);

                }
            });

        },


        showReferenceModal(projectId, entryId, referenceIndex = -1) {

            const project = this.getProjectById(projectId);
            const entry = this.getWorldEntry(project, entryId);

            if (!project || !entry) {
                this.core.notify("World entry could not be found.", "error");
                return;
            }

            if (!this.modalContainer) {
                this.modalContainer = document.getElementById("modal-container");
            }

            if (!this.modalContainer) {
                return;
            }

            const currentReferences = Array.isArray(entry.references)
                ? entry.references
                : [];

            const editingReference = referenceIndex >= 0
                ? currentReferences[referenceIndex] || null
                : null;

            const worldCandidates = this.getWorldEntries(project)
                .filter(item => item.id !== entry.id);

            const characterCandidates = Array.isArray(project?.story?.characters)
                ? project.story.characters.filter(character => character && character.id)
                : [];

            const targetKind = String(editingReference?.targetKind || "world");

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="world-reference-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">WORLD REFERENCE</p>
                                <h2 id="world-reference-modal-title">${editingReference ? "Edit Reference" : "Add Reference"}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-world-reference-modal" aria-label="Close reference form">×</button>
                        </header>

                        <form id="world-reference-form" class="project-form" novalidate>
                            <div class="project-form-grid">

                                <label class="form-field" for="world-reference-target-kind-input">
                                    <span>Target Type</span>
                                    <select id="world-reference-target-kind-input" name="targetKind">
                                        <option value="world" ${targetKind === "world" ? "selected" : ""}>World Entry</option>
                                        <option value="character" ${targetKind === "character" ? "selected" : ""}>Character</option>
                                    </select>
                                </label>

                                <label class="form-field form-field-wide" for="world-reference-target-entry-input">
                                    <span>Target</span>
                                    <select id="world-reference-target-entry-input" name="targetEntryId" required></select>
                                </label>

                                <label class="form-field" for="world-reference-type-input">
                                    <span>Relationship Type</span>
                                    <input id="world-reference-type-input" name="relationshipType" type="text" autocomplete="off" value="${this.escapeHTML(editingReference?.relationshipType || "Related")}" />
                                </label>

                                <label class="form-field form-field-wide" for="world-reference-description-input">
                                    <span>Description</span>
                                    <textarea id="world-reference-description-input" name="description" rows="3">${this.escapeHTML(editingReference?.description || "")}</textarea>
                                </label>

                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-world-reference-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${editingReference ? "Save Reference" : "Add Reference"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-world-reference-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            const targetKindInput = this.modalContainer.querySelector("#world-reference-target-kind-input");
            const targetEntryInput = this.modalContainer.querySelector("#world-reference-target-entry-input");

            const renderTargetOptions = () => {

                if (!targetEntryInput) {
                    return;
                }

                const selectedKind = String(targetKindInput?.value || "world");
                const selectedTarget = String(editingReference?.targetEntryId || "").trim();

                if (selectedKind === "character") {

                    targetEntryInput.innerHTML = `
                        <option value="">Select a character</option>
                        ${characterCandidates.map(candidate => {
                            const label = String(candidate.displayName || candidate.name || "Unnamed Character");
                            const id = String(candidate.id || "");
                            return `
                                <option value="${this.escapeHTML(id)}" ${selectedTarget === id ? "selected" : ""}>
                                    ${this.escapeHTML(label)}
                                </option>
                            `;
                        }).join("")}
                    `;

                    return;
                }

                targetEntryInput.innerHTML = `
                    <option value="">Select a world entry</option>
                    ${worldCandidates.map(candidate => {
                        const id = String(candidate.id || "");
                        return `
                            <option value="${this.escapeHTML(id)}" ${selectedTarget === id ? "selected" : ""}>
                                ${this.escapeHTML(this.getEntryTitle(candidate))}
                            </option>
                        `;
                    }).join("")}
                `;

            };

            renderTargetOptions();

            targetKindInput?.addEventListener("change", () => {
                renderTargetOptions();
            });

            this.modalContainer.querySelector("#world-reference-form")?.addEventListener("submit", event => {
                event.preventDefault();

                this.handleReferenceSubmit(
                    projectId,
                    entry.id,
                    referenceIndex,
                    event.currentTarget
                );

            });

        },


        handleReferenceSubmit(projectId, entryId, referenceIndex, form) {

            const formData = new FormData(form);

            const targetKind = String(formData.get("targetKind") || "world").trim().toLowerCase() === "character"
                ? "character"
                : "world";

            const targetEntryId = String(formData.get("targetEntryId") || "").trim();
            const relationshipType = String(formData.get("relationshipType") || "Related").trim() || "Related";
            const description = String(formData.get("description") || "");

            if (!targetEntryId) {
                this.core.notify("Select a target.", "error");
                form.querySelector('[name="targetEntryId"]')?.focus();
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            if (targetKind === "world") {

                if (targetEntryId === entryId) {
                    this.core.notify("A world entry cannot reference itself.", "error");
                    return;
                }

                const targetWorld = this.getWorldEntry(project, targetEntryId);

                if (!targetWorld || targetWorld.projectId !== projectId) {
                    this.core.notify("Invalid world entry target.", "error");
                    return;
                }

            } else {

                const targetCharacter = Array.isArray(project?.story?.characters)
                    ? project.story.characters.find(character => String(character?.id || "") === targetEntryId)
                    : null;

                if (!targetCharacter || String(targetCharacter?.projectId || projectId) !== projectId) {
                    this.core.notify("Invalid character target.", "error");
                    return;
                }

            }

            const saved = this.updateProjectWorldEntries(
                projectId,
                entries => {

                    const index = entries.findIndex(entry => entry.id === entryId);

                    if (index === -1) {
                        return null;
                    }

                    const sourceEntry = entries[index];
                    const existingReferences = Array.isArray(sourceEntry.references)
                        ? [...sourceEntry.references]
                        : [];

                    const nextReference = {
                        sourceEntryId: sourceEntry.id,
                        targetEntryId,
                        targetKind,
                        relationshipType,
                        description,
                        projectId
                    };

                    if (referenceIndex >= 0 && referenceIndex < existingReferences.length) {
                        existingReferences[referenceIndex] = nextReference;
                    } else {
                        existingReferences.push(nextReference);
                    }

                    const now = new Date().toISOString();

                    const nextEntry = {
                        ...sourceEntry,
                        references: existingReferences,
                        updatedAt: now
                    };

                    const normalized = this.normalizeWorldEntry(nextEntry, projectId);

                    if (!normalized) {
                        return null;
                    }

                    const nextEntries = [...entries];
                    nextEntries[index] = normalized;
                    return nextEntries;

                },
                "world-reference-save"
            );

            if (!saved) {
                this.core.notify("Failed to save reference.", "error");
                return;
            }

            this.closeModal();
            this.selectedEntryId = entryId;
            this.core.notify(
                referenceIndex >= 0
                    ? "Reference updated."
                    : "Reference added.",
                "success"
            );
            this.render(this.container);

        },


        removeReference(projectId, entryId, referenceIndex) {

            const saved = this.updateProjectWorldEntries(
                projectId,
                entries => {

                    const index = entries.findIndex(entry => entry.id === entryId);

                    if (index === -1) {
                        return null;
                    }

                    const sourceEntry = entries[index];
                    const existing = Array.isArray(sourceEntry.references)
                        ? [...sourceEntry.references]
                        : [];

                    if (
                        referenceIndex < 0 ||
                        referenceIndex >= existing.length
                    ) {
                        return null;
                    }

                    existing.splice(referenceIndex, 1);

                    const now = new Date().toISOString();

                    const nextEntry = this.normalizeWorldEntry(
                        {
                            ...sourceEntry,
                            references: existing,
                            updatedAt: now
                        },
                        projectId
                    );

                    if (!nextEntry) {
                        return null;
                    }

                    const nextEntries = [...entries];
                    nextEntries[index] = nextEntry;
                    return nextEntries;

                },
                "world-reference-remove"
            );

            if (!saved) {
                this.core.notify("Failed to remove reference.", "error");
                return;
            }

            this.selectedEntryId = entryId;
            this.core.notify("Reference removed.", "success");
            this.render(this.container);

        },


        updateProjectWorldEntries(projectId, updater, source, onSuccess) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return false;
            }

            const hydrated = this.ensureProjectWorldShape(project);
            const nextProject = this.cloneData(hydrated.project);

            if (!nextProject) {
                return false;
            }

            const currentEntries = this.getWorldEntries(nextProject);
            const nextEntries = updater(currentEntries);

            if (!Array.isArray(nextEntries)) {
                return false;
            }

            const now = new Date().toISOString();

            nextProject.story.worldEntries = nextEntries;
            nextProject.statistics = {
                ...(nextProject.statistics || {}),
                world: nextEntries.filter(entry => entry.status !== "Archived").length
            };
            nextProject.updatedAt = now;
            nextProject.lastModified = now;

            if (!this.persistProject(nextProject, source || "world-update")) {
                return false;
            }

            if (typeof onSuccess === "function") {
                onSuccess(nextEntries);
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

                const saved = projectsModule.saveProjects(next, { source: source || "world" });

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


        getWorldSummaryCounts(projectId = null) {

            const targetProject = projectId
                ? this.getProjectById(projectId)
                : this.getActiveProject();

            if (!targetProject) {
                return {
                    total: 0,
                    active: 0,
                    archived: 0,
                    byType: {}
                };
            }

            const entries = this.getWorldEntries(targetProject);
            const byType = {};

            entries.forEach(entry => {
                const type = this.resolveEntryTypeMeta(entry.type).filterCategory;
                byType[type] = (byType[type] || 0) + 1;
            });

            return {
                total: entries.length,
                active: entries.filter(entry => entry.status !== "Archived").length,
                archived: entries.filter(entry => entry.status === "Archived").length,
                byType
            };

        },


        getTypeFieldDefinitions(type) {

            return this.getTypeTemplateSections(type)
                .flatMap(section => Array.isArray(section.fields) ? section.fields : []);

        },


        getTypeTemplateSections(type) {

            const map = {
                "Location": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "locationType", label: "Location Type", control: "input" },
                            { key: "parentLocation", label: "Parent Location", control: "input" },
                            { key: "firstAppearance", label: "First Appearance", control: "input" }
                        ]
                    },
                    {
                        title: "Structure",
                        fields: [
                            { key: "appearance", label: "Appearance" },
                            { key: "environment", label: "Environment" },
                            { key: "geography", label: "Geography" },
                            { key: "architecture", label: "Architecture" },
                            { key: "residents", label: "Residents" },
                            { key: "importantPlaces", label: "Important Places" }
                        ]
                    },
                    {
                        title: "Relationships",
                        fields: [
                            { key: "connectedCharacters", label: "Connected Characters" },
                            { key: "connectedPlotThreads", label: "Connected Plot Threads" }
                        ]
                    },
                    {
                        title: "Timeline",
                        fields: [
                            { key: "importantEvents", label: "Important Events" }
                        ]
                    }
                ],
                "Organisation": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "organisationType", label: "Organisation Type", control: "input" },
                            { key: "headquarters", label: "Headquarters", control: "input" }
                        ]
                    },
                    {
                        title: "Structure",
                        fields: [
                            { key: "leadershipStructure", label: "Leadership Structure" },
                            { key: "ranks", label: "Ranks" },
                            { key: "departments", label: "Departments" },
                            { key: "activities", label: "Activities" }
                        ]
                    },
                    {
                        title: "Relationships",
                        fields: [
                            { key: "allies", label: "Allies" },
                            { key: "rivals", label: "Rivals" },
                            { key: "importantCharacters", label: "Important Characters" },
                            { key: "plotThreads", label: "Plot Threads" }
                        ]
                    }
                ],
                "Faction": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "factionType", label: "Faction Type", control: "input" },
                            { key: "ideology", label: "Ideology" },
                            { key: "values", label: "Values" },
                            { key: "motivations", label: "Motivations" }
                        ]
                    },
                    {
                        title: "Structure",
                        fields: [
                            { key: "goals", label: "Goals" },
                            { key: "keyMembers", label: "Key Members" },
                            { key: "primaryTerritory", label: "Primary Territory" },
                            { key: "areasOfInfluence", label: "Areas Of Influence" }
                        ]
                    },
                    {
                        title: "Conflicts",
                        fields: [
                            { key: "currentConflicts", label: "Current Conflicts" },
                            { key: "historicalConflicts", label: "Historical Conflicts" }
                        ]
                    }
                ],
                "Culture": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "cultureType", label: "Culture Type", control: "input" },
                            { key: "originStory", label: "Origin Story" },
                            { key: "primaryLanguage", label: "Primary Language", control: "input" },
                            { key: "importantFigures", label: "Important Figures" }
                        ]
                    },
                    {
                        title: "Structure",
                        fields: [
                            { key: "familyStructure", label: "Family Structure" },
                            { key: "socialClasses", label: "Social Classes" },
                            { key: "religion", label: "Religion" },
                            { key: "taboos", label: "Taboos" }
                        ]
                    },
                    {
                        title: "Timeline",
                        fields: [
                            { key: "festivals", label: "Festivals" },
                            { key: "ceremonies", label: "Ceremonies" }
                        ]
                    }
                ],
                "System": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "systemType", label: "System Type", control: "input" },
                            { key: "whoCanUseIt", label: "Who Can Use It" },
                            { key: "training", label: "Training" }
                        ]
                    },
                    {
                        title: "Rules",
                        fields: [
                            { key: "coreRules", label: "Core Rules" },
                            { key: "requirements", label: "Requirements" },
                            { key: "exceptions", label: "Exceptions" },
                            { key: "restrictions", label: "Restrictions" }
                        ]
                    },
                    {
                        title: "Components",
                        fields: [
                            { key: "components", label: "Components" },
                            { key: "requiredResources", label: "Required Resources" }
                        ]
                    },
                    {
                        title: "Timeline & Consequences",
                        fields: [
                            { key: "sideEffects", label: "Side Effects" }
                        ]
                    }
                ],
                "Object": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "objectType", label: "Object Type", control: "input" },
                            { key: "creator", label: "Creator", control: "input" },
                            { key: "currentOwner", label: "Current Owner", control: "input" },
                            { key: "currentLocation", label: "Current Location", control: "input" }
                        ]
                    },
                    {
                        title: "Structure",
                        fields: [
                            { key: "materials", label: "Materials" },
                            { key: "size", label: "Size", control: "input" },
                            { key: "condition", label: "Condition" },
                            { key: "specialProperties", label: "Special Properties" }
                        ]
                    },
                    {
                        title: "Use",
                        fields: [
                            { key: "abilities", label: "Abilities" },
                            { key: "functions", label: "Functions" }
                        ]
                    },
                    {
                        title: "Significance",
                        fields: [
                            { key: "culturalSignificance", label: "Cultural Significance" }
                        ]
                    }
                ],
                "Lore": [
                    {
                        title: "Identity",
                        fields: [
                            { key: "loreType", label: "Lore Type", control: "input" },
                            { key: "truthStatus", label: "Truth Status", control: "input" }
                        ]
                    },
                    {
                        title: "Content",
                        fields: [
                            { key: "storyContent", label: "Story Content" },
                            { key: "historicalContext", label: "Historical Context" },
                            { key: "knownEvents", label: "Known Events" }
                        ]
                    },
                    {
                        title: "Timeline",
                        fields: [
                            { key: "developmentOverTime", label: "Development Over Time" }
                        ]
                    },
                    {
                        title: "Sources & Audience",
                        fields: [
                            { key: "whoBelievesIt", label: "Who Believes It" },
                            { key: "historicalSources", label: "Historical Sources" },
                            { key: "writtenSources", label: "Written Sources" },
                            { key: "researchers", label: "Researchers" }
                        ]
                    }
                ]
            };

            const meta = this.resolveEntryTypeMeta(type);
            if (meta.isCustom) {
                return [];
            }

            return map[meta.storedType] || [];

        },


        getCategoryFieldKeys() {

            const all = [];

            this.typeCatalog
                .filter(type => type.key !== "custom")
                .forEach(type => {
                this.getTypeFieldDefinitions(type.label).forEach(field => {
                    all.push(field.key);
                });
            });

            return [...new Set(all)];

        },


        getEntryTitle(entry) {
            return String(entry?.title || "Untitled Entry").trim() || "Untitled Entry";
        },


        isAllowedStatus(status) {
            return this.statusValues.includes(String(status || "").trim());
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
                console.error("World clone failed:", error);
                return null;
            }

        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
