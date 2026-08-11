/*
=========================================================
AUTHOROS
CHARACTERS MODULE
Milestone 16
=========================================================
*/

(function () {

    "use strict";

    const CHARACTER_ROLE_CATALOG = [
        {
            key: "protagonist",
            label: "Protagonist",
            description: "Main character driving the story.",
            aliases: ["protagonist", "main character"]
        },
        {
            key: "antagonist",
            label: "Antagonist",
            description: "Primary opposing character or force.",
            aliases: ["antagonist", "villain"]
        },
        {
            key: "minor",
            label: "Minor Character",
            description: "Supporting character with a smaller narrative role.",
            aliases: ["minor", "supporting", "mentor"]
        },
        {
            key: "love_interest",
            label: "Love Interest",
            description: "Character with a significant romantic or emotional role.",
            aliases: ["love interest", "love_interest"]
        },
        {
            key: "custom",
            label: "Custom",
            description: "Minimal template with fully customisable fields.",
            aliases: ["custom", "other"]
        }
    ];

    const FIELD_TYPE_CATALOG = [
        { key: "text", label: "Text" },
        { key: "long-text", label: "Long Text" },
        { key: "rich-text", label: "Rich Text" },
        { key: "number", label: "Number" },
        { key: "date", label: "Date" },
        { key: "checkbox", label: "Checkbox" },
        { key: "select", label: "Select" },
        { key: "multi-select", label: "Multi-Select" },
        { key: "relationship", label: "Relationship" },
        { key: "url", label: "URL" },
        { key: "image", label: "Image" }
    ];

    const STATUS_VALUES = [
        "Draft",
        "Developing",
        "Established",
        "Archived"
    ];

    const ROLE_FILTER_VALUES = [
        "Protagonist",
        "Antagonist",
        "Minor Character",
        "Love Interest",
        "Custom"
    ];

    const RELATIONSHIP_ENTITY_KINDS = [
        { key: "character", label: "Character" },
        { key: "world", label: "World Entry" },
        { key: "chapter", label: "Chapter" },
        { key: "plotScene", label: "Plot Scene" },
        { key: "timelineEvent", label: "Timeline Event" },
        { key: "project", label: "Project" }
    ];

    const LEGACY_FIELD_META = {
        summary: { label: "Summary", fieldType: "long-text" },
        description: { label: "Description", fieldType: "long-text" },
        physical_description: { label: "Physical Description", fieldType: "long-text" },
        personality: { label: "Personality", fieldType: "long-text" },
        background: { label: "Background", fieldType: "long-text" },
        goals: { label: "Goals", fieldType: "long-text" },
        motivations: { label: "Motivations", fieldType: "long-text" },
        fears: { label: "Fears", fieldType: "long-text" },
        strengths: { label: "Strengths", fieldType: "long-text" },
        weaknesses: { label: "Weaknesses", fieldType: "long-text" },
        notes: { label: "Notes", fieldType: "long-text" }
    };

    const TEMPLATE_DEFINITIONS = {
        protagonist: [
            ["basic_information", "Basic Information", [
                ["full_name", "Full Name", "text"],
                ["age", "Age", "number"],
                ["pronouns", "Pronouns", "text"],
                ["summary", "Summary", "long-text"],
                ["description", "Description", "long-text"]
            ]],
            ["appearance", "Appearance", [
                ["physical_description", "Physical Description", "long-text"],
                ["hair", "Hair", "text"],
                ["eyes", "Eyes", "text"],
                ["height", "Height", "text"],
                ["build", "Build", "text"],
                ["distinguishing_features", "Distinguishing Features", "long-text"],
                ["clothing_style", "Clothing / Style", "long-text"]
            ]],
            ["personality", "Personality", [
                ["personality", "Personality", "long-text"],
                ["strengths", "Strengths", "long-text"],
                ["weaknesses", "Weaknesses", "long-text"],
                ["habits", "Habits", "long-text"],
                ["quirks", "Quirks", "long-text"],
                ["fears", "Fears", "long-text"],
                ["values", "Values", "long-text"]
            ]],
            ["character_motivation", "Character Motivation", [
                ["goals", "Primary Goal", "long-text"],
                ["secondary_goals", "Secondary Goals", "long-text"],
                ["motivations", "Motivation", "long-text"],
                ["internal_need", "Internal Need", "long-text"],
                ["external_goal", "External Goal", "long-text"]
            ]],
            ["character_arc", "Character Arc", [
                ["starting_point", "Starting Point", "long-text"],
                ["internal_conflict", "Internal Conflict", "long-text"],
                ["external_conflict", "External Conflict", "long-text"],
                ["character_development", "Character Development", "long-text"],
                ["midpoint_change", "Midpoint Change", "long-text"],
                ["lowest_point", "Lowest Point", "long-text"],
                ["final_transformation", "Final Transformation", "long-text"],
                ["ending_state", "Ending State", "long-text"]
            ]],
            ["story_function", "Story Function", [
                ["story_role", "Story Role", "text"],
                ["narrative_purpose", "Narrative Purpose", "long-text"],
                ["stakes", "Stakes", "long-text"],
                ["major_conflicts", "Major Conflicts", "long-text"],
                ["major_decisions", "Major Decisions", "long-text"]
            ]],
            ["relationships", "Relationships", [
                ["family", "Family", "long-text"],
                ["friends", "Friends", "long-text"],
                ["allies", "Allies", "long-text"],
                ["rivals", "Rivals", "long-text"],
                ["enemies", "Enemies", "long-text"],
                ["love_interests", "Love Interests", "long-text"]
            ]],
            ["story_tracking", "Story Tracking", [
                ["first_appearance", "First Appearance", "text"],
                ["important_chapters", "Important Chapters", "long-text"],
                ["important_scenes", "Important Scenes", "long-text"],
                ["major_events", "Major Events", "long-text"],
                ["plot_threads", "Plot Threads", "long-text"]
            ]],
            ["notes", "Notes", [
                ["notes", "General Notes", "long-text"],
                ["research", "Research", "long-text"],
                ["author_notes", "Author Notes", "long-text"]
            ]]
        ],
        antagonist: [
            ["basic_information", "Basic Information", [
                ["full_name", "Full Name", "text"],
                ["age", "Age", "number"],
                ["pronouns", "Pronouns", "text"],
                ["summary", "Summary", "long-text"],
                ["description", "Description", "long-text"]
            ]],
            ["appearance", "Appearance", [
                ["physical_description", "Physical Description", "long-text"],
                ["distinguishing_features", "Distinguishing Features", "long-text"],
                ["clothing_style", "Clothing / Style", "long-text"]
            ]],
            ["personality", "Personality", [
                ["personality", "Personality", "long-text"],
                ["strengths", "Strengths", "long-text"],
                ["weaknesses", "Weaknesses", "long-text"],
                ["habits", "Habits", "long-text"],
                ["fears", "Fears", "long-text"],
                ["values", "Values", "long-text"]
            ]],
            ["motivation", "Motivation", [
                ["goals", "Primary Goal", "long-text"],
                ["secondary_goals", "Secondary Goals", "long-text"],
                ["motivations", "Motivation", "long-text"],
                ["desire", "Desire", "long-text"],
                ["core_belief", "Core Belief", "long-text"]
            ]],
            ["opposition", "Opposition", [
                ["oppose_protagonist", "Why They Oppose the Protagonist", "long-text"],
                ["main_conflict", "Main Conflict", "long-text"],
                ["resources", "Resources", "long-text"],
                ["influence", "Influence", "long-text"],
                ["threat_level", "Threat Level", "text"]
            ]],
            ["antagonist_arc", "Villain / Antagonist Arc", [
                ["origin", "Origin", "long-text"],
                ["turning_point", "Turning Point", "long-text"],
                ["escalation", "Escalation", "long-text"],
                ["major_decisions", "Major Decisions", "long-text"],
                ["defeat_resolution", "Defeat / Resolution", "long-text"],
                ["ending_state", "Ending State", "long-text"]
            ]],
            ["relationships", "Relationships", [
                ["allies", "Allies", "long-text"],
                ["followers", "Followers", "long-text"],
                ["rivals", "Rivals", "long-text"],
                ["enemies", "Enemies", "long-text"],
                ["target_characters", "Target Characters", "long-text"]
            ]],
            ["story_tracking", "Story Tracking", [
                ["first_appearance", "First Appearance", "text"],
                ["important_chapters", "Important Chapters", "long-text"],
                ["important_scenes", "Important Scenes", "long-text"],
                ["major_events", "Major Events", "long-text"],
                ["plot_threads", "Plot Threads", "long-text"]
            ]],
            ["notes", "Notes", [
                ["notes", "General Notes", "long-text"],
                ["research", "Research", "long-text"],
                ["author_notes", "Author Notes", "long-text"]
            ]]
        ],
        minor: [
            ["basic_information", "Basic Information", [
                ["full_name", "Full Name", "text"],
                ["age", "Age", "number"],
                ["pronouns", "Pronouns", "text"],
                ["description", "Description", "long-text"]
            ]],
            ["appearance", "Appearance", [
                ["physical_description", "Physical Description", "long-text"],
                ["distinguishing_features", "Distinguishing Features", "long-text"],
                ["clothing_style", "Clothing / Style", "long-text"]
            ]],
            ["personality", "Personality", [
                ["personality", "Personality", "long-text"],
                ["traits", "Traits", "long-text"],
                ["habits", "Habits", "long-text"],
                ["strengths", "Strengths", "long-text"],
                ["weaknesses", "Weaknesses", "long-text"]
            ]],
            ["story_function", "Story Function", [
                ["narrative_purpose", "Narrative Purpose", "long-text"],
                ["connection_main_story", "Connection to Main Story", "long-text"],
                ["information_provide", "Information They Provide", "long-text"],
                ["conflict_contribution", "Conflict Contribution", "long-text"]
            ]],
            ["relationships", "Relationships", [
                ["family", "Family", "long-text"],
                ["friends", "Friends", "long-text"],
                ["allies", "Allies", "long-text"],
                ["rivals", "Rivals", "long-text"],
                ["enemies", "Enemies", "long-text"]
            ]],
            ["story_tracking", "Story Tracking", [
                ["first_appearance", "First Appearance", "text"],
                ["chapters", "Chapters", "long-text"],
                ["scenes", "Scenes", "long-text"],
                ["events", "Events", "long-text"]
            ]],
            ["notes", "Notes", [
                ["notes", "General Notes", "long-text"],
                ["research", "Research", "long-text"],
                ["author_notes", "Author Notes", "long-text"]
            ]]
        ],
        love_interest: [
            ["basic_information", "Basic Information", [
                ["full_name", "Full Name", "text"],
                ["age", "Age", "number"],
                ["pronouns", "Pronouns", "text"],
                ["description", "Description", "long-text"]
            ]],
            ["appearance", "Appearance", [
                ["physical_description", "Physical Description", "long-text"],
                ["distinguishing_features", "Distinguishing Features", "long-text"],
                ["clothing_style", "Clothing / Style", "long-text"]
            ]],
            ["personality", "Personality", [
                ["personality", "Personality", "long-text"],
                ["strengths", "Strengths", "long-text"],
                ["weaknesses", "Weaknesses", "long-text"],
                ["habits", "Habits", "long-text"],
                ["quirks", "Quirks", "long-text"],
                ["fears", "Fears", "long-text"],
                ["values", "Values", "long-text"]
            ]],
            ["relationship", "Relationship", [
                ["love_interest_of", "Love Interest Of", "relationship"],
                ["relationship_status", "Relationship Status", "text"],
                ["initial_relationship", "Initial Relationship", "long-text"],
                ["attraction", "Attraction", "long-text"],
                ["emotional_connection", "Emotional Connection", "long-text"],
                ["relationship_conflicts", "Relationship Conflicts", "long-text"],
                ["relationship_development", "Relationship Development", "long-text"]
            ]],
            ["romantic_arc", "Romantic Arc", [
                ["first_meeting", "First Meeting", "long-text"],
                ["first_impression", "First Impression", "long-text"],
                ["attraction_development", "Attraction Development", "long-text"],
                ["major_turning_points", "Major Turning Points", "long-text"],
                ["major_conflict", "Major Conflict", "long-text"],
                ["separation_distance", "Separation / Distance", "long-text"],
                ["reconciliation", "Reconciliation", "long-text"],
                ["relationship_resolution", "Relationship Resolution", "long-text"]
            ]],
            ["character_arc", "Character Arc", [
                ["personal_goal", "Personal Goal", "long-text"],
                ["motivations", "Motivation", "long-text"],
                ["internal_conflict", "Internal Conflict", "long-text"],
                ["external_conflict", "External Conflict", "long-text"],
                ["development", "Development", "long-text"],
                ["ending_state", "Ending State", "long-text"]
            ]],
            ["story_tracking", "Story Tracking", [
                ["first_appearance", "First Appearance", "text"],
                ["important_chapters", "Important Chapters", "long-text"],
                ["important_scenes", "Important Scenes", "long-text"],
                ["major_events", "Major Events", "long-text"],
                ["plot_threads", "Plot Threads", "long-text"]
            ]],
            ["notes", "Notes", [
                ["notes", "General Notes", "long-text"],
                ["research", "Research", "long-text"],
                ["author_notes", "Author Notes", "long-text"]
            ]]
        ],
        custom: [
            ["basic_information", "Basic Information", [
                ["description", "Description", "long-text"]
            ]],
            ["notes", "Notes", [
                ["notes", "Notes", "long-text"]
            ]]
        ]
    };

    window.AuthorOSCharacters = {

        name: "characters",
        core: null,
        container: null,
        modalContainer: null,
        selectedCharacterId: null,
        activeProjectId: null,
        characterFormState: null,

        uiState: {
            search: "",
            status: "All",
            role: "All",
            tag: "All",
            sort: "updated-desc"
        },

        initialize(core) {
            this.core = core;
            this.modalContainer = document.getElementById("modal-container");

            this.core.events.on("navigation:changed", navigation => {
                if (navigation?.route === "characters" && this.container) {
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

            const hydrated = this.ensureProjectCharacterShape(project);

            if (hydrated.changed) {
                this.persistProject(hydrated.project, "characters-hydrate");
            }

            const currentProject = this.getProjectById(project.id) || hydrated.project;
            this.activeProjectId = currentProject.id;

            const characters = this.getCharacters(currentProject);

            if (this.selectedCharacterId && !characters.some(character => character.id === this.selectedCharacterId)) {
                this.selectedCharacterId = null;
            }

            const filtered = this.getFilteredCharacters(characters);
            const selected = this.selectedCharacterId
                ? this.getCharacter(currentProject, this.selectedCharacterId)
                : null;

            container.innerHTML = `
                <section class="characters-view library-view">
                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">CHARACTER STUDIO</p>
                            <h1>Characters</h1>
                            <p class="library-description">Build and manage your project's character bible.</p>
                            <p class="characters-project-context">Project: ${this.escapeHTML(this.getProjectTitle(currentProject))}</p>
                        </div>
                        <div class="library-actions">
                            <button type="button" class="button button-primary" data-action="new-character">+ New Character</button>
                        </div>
                    </header>

                    ${this.renderLibraryControls(characters)}

                    <div class="library-results-bar">
                        <span class="library-count">${filtered.length} ${filtered.length === 1 ? "Character" : "Characters"}</span>
                        ${this.hasActiveFilters() ? `<span class="library-filter-state">Filtered from ${characters.length} ${characters.length === 1 ? "character" : "characters"}</span>` : ""}
                    </div>

                    <div class="characters-layout ${selected ? "with-detail" : ""}">
                        <div class="characters-library-column">
                            ${filtered.length ? this.renderCharacterGrid(filtered) : this.renderEmptyState(characters.length > 0)}
                        </div>
                        <aside class="characters-detail-column" aria-label="Character detail panel">
                            ${selected ? this.renderCharacterDetail(selected, currentProject) : this.renderDetailEmptyState()}
                        </aside>
                    </div>
                </section>
            `;

            this.bindEvents(container, currentProject.id);
        },

        renderMissingProjectState() {
            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">*</div>
                    <p class="eyebrow">CHARACTER STUDIO</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to manage characters.</p>
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
            return activeProjectId ? this.getProjectById(activeProjectId) : null;
        },

        getProjectById(projectId) {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects)
                ? projects.find(project => project.id === projectId) || null
                : null;
        },

        getProjectTitle(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        },

        resolveRoleMeta(roleValue, customRoleName = "") {
            const explicitKey = String(roleValue || "").trim().toLowerCase();
            const customLabel = String(customRoleName || "").trim();

            if (!explicitKey) {
                return {
                    key: "minor",
                    label: "Minor Character",
                    description: CHARACTER_ROLE_CATALOG[2].description,
                    isCustom: false,
                    displayRole: "Minor Character",
                    filterRole: "Minor Character"
                };
            }

            const direct = CHARACTER_ROLE_CATALOG.find(role => role.key === explicitKey);
            if (direct && direct.key !== "custom") {
                return {
                    key: direct.key,
                    label: direct.label,
                    description: direct.description,
                    isCustom: false,
                    displayRole: direct.label,
                    filterRole: direct.label
                };
            }

            const byAlias = CHARACTER_ROLE_CATALOG.find(role => role.aliases.some(alias => alias.toLowerCase() === explicitKey));
            if (byAlias && byAlias.key !== "custom") {
                return {
                    key: byAlias.key,
                    label: byAlias.label,
                    description: byAlias.description,
                    isCustom: false,
                    displayRole: byAlias.label,
                    filterRole: byAlias.label
                };
            }

            const displayRole = customLabel || String(roleValue || "").trim() || "Custom";
            return {
                key: "custom",
                label: "Custom",
                description: CHARACTER_ROLE_CATALOG[4].description,
                isCustom: true,
                displayRole,
                filterRole: "Custom"
            };
        },

        getRoleTemplateId(roleId) {
            return `character-template-${String(roleId || "custom").trim().toLowerCase() || "custom"}`;
        },

        getRoleSelectorCatalog() {
            return CHARACTER_ROLE_CATALOG.map(role => ({
                key: role.key,
                label: role.label,
                description: role.description
            }));
        },

        getFieldTypeMeta(fieldType) {
            const normalized = String(fieldType || "text").trim().toLowerCase();
            return FIELD_TYPE_CATALOG.find(item => item.key === normalized) || FIELD_TYPE_CATALOG[0];
        },

        getRoleTemplateSections(roleId) {
            const template = TEMPLATE_DEFINITIONS[String(roleId || "custom").trim().toLowerCase()] || TEMPLATE_DEFINITIONS.custom;
            let orderSeed = 1;

            return template.map((section, sectionIndex) => ({
                id: section[0],
                label: section[1],
                order: sectionIndex + 1,
                fields: section[2].map(field => {
                    const definition = {
                        id: field[0],
                        label: field[1],
                        fieldType: field[2] || "long-text",
                        sectionId: section[0],
                        sectionLabel: section[1],
                        order: orderSeed,
                        required: false,
                        isCustom: false,
                        description: "",
                        options: [],
                        defaultValue: this.getDefaultFieldValue(field[2] || "long-text")
                    };

                    orderSeed += 1;
                    return definition;
                })
            }));
        },

        getDefaultFieldValue(fieldType) {
            const type = this.getFieldTypeMeta(fieldType).key;
            if (type === "checkbox") {
                return false;
            }
            if (type === "multi-select") {
                return [];
            }
            if (type === "image") {
                return null;
            }
            return "";
        },

        ensureProjectCharacterShape(project) {
            const next = this.cloneData(project);
            if (!next) {
                return { project, changed: false };
            }

            let changed = false;

            if (!next.story || typeof next.story !== "object") {
                next.story = {};
                changed = true;
            }

            if (!Array.isArray(next.story.characters)) {
                next.story.characters = [];
                changed = true;
            }

            const seen = new Set();

            next.story.characters = next.story.characters
                .map(candidate => {
                    const normalized = this.normalizeCharacter(candidate, next.id);
                    if (!normalized) {
                        changed = true;
                        return null;
                    }
                    if (JSON.stringify(candidate) !== JSON.stringify(normalized)) {
                        changed = true;
                    }
                    return normalized;
                })
                .filter(Boolean)
                .map(character => {
                    if (!seen.has(character.id)) {
                        seen.add(character.id);
                        return character;
                    }
                    changed = true;
                    const replacement = {
                        ...character,
                        id: AuthorOSHelpers.generateId("character")
                    };
                    seen.add(replacement.id);
                    return replacement;
                });

            const activeCount = next.story.characters.filter(character => character.status !== "Archived").length;

            if (!next.statistics || typeof next.statistics !== "object") {
                next.statistics = {};
                changed = true;
            }

            if (Number(next.statistics.characters || 0) !== activeCount) {
                next.statistics.characters = activeCount;
                changed = true;
            }

            return { project: next, changed };
        },

        normalizeCharacter(candidate, projectId) {
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

            const roleMeta = this.resolveRoleMeta(
                candidate.primaryRoleId || candidate.role,
                candidate.customRoleName || (candidate.primaryRoleId === "custom" ? candidate.role : "")
            );

            const status = STATUS_VALUES.includes(String(candidate.status || "").trim())
                ? String(candidate.status).trim()
                : "Draft";
            const tags = Array.isArray(candidate.tags)
                ? candidate.tags.map(tag => String(tag || "").trim()).filter(Boolean)
                : [];
            const relationships = Array.isArray(candidate.relationships)
                ? candidate.relationships.map(item => this.normalizeRelationship(item, projectId)).filter(Boolean)
                : [];
            const createdAt = this.normalizeDateValue(candidate.createdAt, now);
            const updatedAt = this.normalizeDateValue(candidate.updatedAt, createdAt);
            const name = String(candidate.name || candidate.displayName || "").trim() || "Untitled Character";
            const displayName = String(candidate.displayName || "").trim();
            const customFields = this.normalizeCustomFields(candidate.customFields);
            const fieldOverrides = this.normalizeFieldOverrides(candidate.fieldOverrides);
            const sectionOverrides = this.normalizeSectionOverrides(candidate.sectionOverrides);
            const mergedFieldValues = this.buildInitialFieldValues(candidate, customFields, fieldOverrides);

            this.promoteLegacyValuesToCustom(roleMeta.key, mergedFieldValues, customFields, fieldOverrides);

            const resolvedDefinitions = this.getResolvedFieldDefinitions({
                primaryRoleId: roleMeta.key,
                customFields,
                fieldOverrides
            });

            const normalizedFieldValues = {};

            resolvedDefinitions.forEach(field => {
                normalizedFieldValues[field.id] = this.normalizeFieldValue(
                    field,
                    Object.prototype.hasOwnProperty.call(mergedFieldValues, field.id)
                        ? mergedFieldValues[field.id]
                        : field.defaultValue
                );
            });

            Object.keys(mergedFieldValues).forEach(key => {
                if (!Object.prototype.hasOwnProperty.call(normalizedFieldValues, key)) {
                    normalizedFieldValues[key] = mergedFieldValues[key];
                }
            });

            return {
                id: typeof candidate.id === "string" && candidate.id.trim()
                    ? candidate.id.trim()
                    : AuthorOSHelpers.generateId("character"),
                projectId,
                name,
                displayName,
                role: roleMeta.displayRole,
                primaryRoleId: roleMeta.key,
                customRoleName: roleMeta.isCustom ? roleMeta.displayRole : "",
                templateId: String(candidate.templateId || this.getRoleTemplateId(roleMeta.key)).trim() || this.getRoleTemplateId(roleMeta.key),
                templateVersion: Number.isFinite(Number(candidate.templateVersion))
                    ? Math.max(1, Math.trunc(Number(candidate.templateVersion)))
                    : 1,
                status,
                tags,
                relationships,
                fieldValues: normalizedFieldValues,
                fieldOverrides,
                sectionOverrides,
                customFields,
                summary: String(normalizedFieldValues.summary || candidate.summary || ""),
                description: String(normalizedFieldValues.description || candidate.description || ""),
                appearance: String(normalizedFieldValues.physical_description || candidate.appearance || ""),
                personality: String(normalizedFieldValues.personality || candidate.personality || ""),
                background: String(normalizedFieldValues.background || candidate.background || ""),
                goals: String(normalizedFieldValues.goals || candidate.goals || ""),
                motivations: String(normalizedFieldValues.motivations || candidate.motivations || ""),
                fears: String(normalizedFieldValues.fears || candidate.fears || ""),
                strengths: String(normalizedFieldValues.strengths || candidate.strengths || ""),
                weaknesses: String(normalizedFieldValues.weaknesses || candidate.weaknesses || ""),
                notes: String(normalizedFieldValues.notes || candidate.notes || ""),
                fieldSearchText: this.buildFieldSearchText(normalizedFieldValues),
                createdAt,
                updatedAt,
                archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
            };
        },

        normalizeRelationship(relationship, projectId) {
            if (!relationship || typeof relationship !== "object") {
                return null;
            }

            const candidateTarget = typeof relationship.targetCharacterId === "string" && relationship.targetCharacterId.trim()
                ? relationship.targetCharacterId.trim()
                : typeof relationship.characterId === "string" && relationship.characterId.trim()
                    ? relationship.characterId.trim()
                    : "";

            return {
                characterId: candidateTarget,
                targetCharacterId: candidateTarget,
                relationshipType: String(relationship.relationshipType || "Other").trim() || "Other",
                description: String(relationship.description || ""),
                projectId
            };
        },

        normalizeFieldOverrides(source) {
            const raw = source && typeof source === "object" && !Array.isArray(source)
                ? source
                : {};
            const result = {};

            Object.keys(raw).forEach(fieldId => {
                const candidate = raw[fieldId];
                if (!candidate || typeof candidate !== "object") {
                    return;
                }
                const normalizedId = String(fieldId || "").trim();
                if (!normalizedId) {
                    return;
                }
                result[normalizedId] = {
                    label: String(candidate.label || "").trim(),
                    description: String(candidate.description || ""),
                    required: Boolean(candidate.required),
                    archived: Boolean(candidate.archived),
                    deleted: Boolean(candidate.deleted),
                    order: Number.isFinite(Number(candidate.order)) ? Math.max(1, Math.trunc(Number(candidate.order))) : null,
                    sectionId: String(candidate.sectionId || "").trim(),
                    sectionLabel: String(candidate.sectionLabel || "").trim(),
                    archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
                };
            });

            return result;
        },

        normalizeCustomFields(source) {
            const fields = Array.isArray(source) ? source : [];
            return fields
                .filter(item => item && typeof item === "object")
                .map((item, index) => {
                    const fieldType = this.getFieldTypeMeta(item.fieldType || item.type).key;
                    const options = Array.isArray(item.options)
                        ? item.options.map(option => String(option || "").trim()).filter(Boolean)
                        : String(item.options || "").split(",").map(option => option.trim()).filter(Boolean);
                    return {
                        id: String(item.id || AuthorOSHelpers.generateId("character_field")).trim() || AuthorOSHelpers.generateId("character_field"),
                        label: String(item.label || item.name || "").trim() || `Custom Field ${index + 1}`,
                        fieldType,
                        description: String(item.description || ""),
                        required: Boolean(item.required),
                        archived: Boolean(item.archived),
                        deleted: Boolean(item.deleted),
                        order: Number.isFinite(Number(item.order)) ? Math.max(1, Math.trunc(Number(item.order))) : 900 + index,
                        sectionId: String(item.sectionId || "custom_fields").trim() || "custom_fields",
                        sectionLabel: String(item.sectionLabel || "Custom Fields").trim() || "Custom Fields",
                        options,
                        defaultValue: item.defaultValue,
                        archivedAt: this.normalizeDateValue(item.archivedAt, null),
                        isCustom: true
                    };
                });
        },

        normalizeSectionOverrides(source) {
            const raw = source && typeof source === "object" && !Array.isArray(source)
                ? source
                : {};
            const result = {};

            Object.keys(raw).forEach(sectionId => {
                const candidate = raw[sectionId];
                if (!candidate || typeof candidate !== "object") {
                    return;
                }

                const normalizedId = String(sectionId || "").trim();
                if (!normalizedId) {
                    return;
                }

                result[normalizedId] = {
                    label: String(candidate.label || "").trim(),
                    archived: Boolean(candidate.archived),
                    order: Number.isFinite(Number(candidate.order)) ? Math.max(1, Math.trunc(Number(candidate.order))) : null,
                    archivedAt: this.normalizeDateValue(candidate.archivedAt, null)
                };
            });

            return result;
        },

        buildInitialFieldValues(candidate, customFields, fieldOverrides) {
            const values = candidate.fieldValues && typeof candidate.fieldValues === "object" && !Array.isArray(candidate.fieldValues)
                ? this.cloneData(candidate.fieldValues) || {}
                : {};

            const legacyMap = {
                summary: candidate.summary,
                description: candidate.description,
                physical_description: candidate.appearance,
                personality: candidate.personality,
                background: candidate.background,
                goals: candidate.goals,
                motivations: candidate.motivations,
                fears: candidate.fears,
                strengths: candidate.strengths,
                weaknesses: candidate.weaknesses,
                notes: candidate.notes,
                display_name: candidate.displayName,
                full_name: candidate.fullName,
                age: candidate.age,
                pronouns: candidate.pronouns
            };

            Object.keys(legacyMap).forEach(key => {
                if (!Object.prototype.hasOwnProperty.call(values, key) && legacyMap[key] !== undefined) {
                    values[key] = legacyMap[key];
                }
            });

            customFields.forEach(field => {
                if (!Object.prototype.hasOwnProperty.call(values, field.id)) {
                    values[field.id] = this.normalizeFieldValue(field, field.defaultValue);
                }
            });

            Object.keys(fieldOverrides).forEach(fieldId => {
                if (!Object.prototype.hasOwnProperty.call(values, fieldId)) {
                    values[fieldId] = "";
                }
            });

            return values;
        },

        promoteLegacyValuesToCustom(roleId, fieldValues, customFields, fieldOverrides) {
            const baseIds = new Set(this.getRoleTemplateSections(roleId).flatMap(section => section.fields.map(field => field.id)));
            const customIds = new Set((Array.isArray(customFields) ? customFields : []).map(field => field.id));

            Object.keys(LEGACY_FIELD_META).forEach((fieldId, index) => {
                const value = fieldValues[fieldId];
                const hasValue = Array.isArray(value)
                    ? value.length > 0
                    : value && typeof value === "object"
                        ? Boolean(Object.keys(value).length)
                        : String(value || "").trim().length > 0;

                if (!hasValue || baseIds.has(fieldId) || customIds.has(fieldId)) {
                    return;
                }

                const meta = LEGACY_FIELD_META[fieldId];
                customFields.push({
                    id: fieldId,
                    label: String(fieldOverrides[fieldId]?.label || meta.label),
                    fieldType: meta.fieldType,
                    description: String(fieldOverrides[fieldId]?.description || ""),
                    required: Boolean(fieldOverrides[fieldId]?.required),
                    archived: Boolean(fieldOverrides[fieldId]?.archived),
                    deleted: Boolean(fieldOverrides[fieldId]?.deleted),
                    order: Number.isFinite(Number(fieldOverrides[fieldId]?.order))
                        ? Math.max(1, Math.trunc(Number(fieldOverrides[fieldId].order)))
                        : 800 + index,
                    sectionId: String(fieldOverrides[fieldId]?.sectionId || "legacy_fields"),
                    sectionLabel: String(fieldOverrides[fieldId]?.sectionLabel || "Legacy Fields"),
                    options: [],
                    defaultValue: "",
                    archivedAt: this.normalizeDateValue(fieldOverrides[fieldId]?.archivedAt, null),
                    isCustom: true
                });
                customIds.add(fieldId);
            });
        },

        getCharacters(project) {
            if (!project?.story?.characters || !Array.isArray(project.story.characters)) {
                return [];
            }
            return project.story.characters.map(character => this.normalizeCharacter(character, project.id)).filter(Boolean);
        },

        getCharacter(project, characterId) {
            if (!project || !characterId) {
                return null;
            }
            return this.getCharacters(project).find(character => character.id === characterId) || null;
        },

        getResolvedFieldDefinitions(character) {
            const roleId = String(character?.primaryRoleId || "minor").trim().toLowerCase() || "minor";
            const baseSections = this.getRoleTemplateSections(roleId);
            const fieldOverrides = character?.fieldOverrides && typeof character.fieldOverrides === "object" ? character.fieldOverrides : {};
            const customFields = Array.isArray(character?.customFields) ? character.customFields : [];
            const definitions = [];

            baseSections.forEach(section => {
                section.fields.forEach(field => {
                    const override = fieldOverrides[field.id] || {};
                    definitions.push({
                        ...field,
                        label: override.label || field.label,
                        description: override.description || "",
                        required: override.required === true || field.required === true,
                        archived: Boolean(override.archived),
                        deleted: Boolean(override.deleted),
                        order: Number.isFinite(Number(override.order)) ? Math.max(1, Math.trunc(Number(override.order))) : field.order,
                        sectionId: override.sectionId || field.sectionId,
                        sectionLabel: override.sectionLabel || field.sectionLabel,
                        archivedAt: this.normalizeDateValue(override.archivedAt, null),
                        isCustom: false
                    });
                });
            });

            customFields.forEach(field => {
                if (!field.deleted) {
                    definitions.push({
                        ...field,
                        isCustom: true,
                        order: Number.isFinite(Number(field.order)) ? Math.max(1, Math.trunc(Number(field.order))) : 900
                    });
                }
            });

            return definitions.filter(field => !field.deleted).sort((left, right) => Number(left.order || 0) - Number(right.order || 0));
        },

        getActiveFieldDefinitions(character) {
            return this.getResolvedFieldDefinitions(character).filter(field => !field.archived);
        },

        getArchivedFieldDefinitions(character) {
            return this.getResolvedFieldDefinitions(character).filter(field => field.archived);
        },

        groupFieldDefinitionsBySection(fields, sectionOverrides = {}) {
            const groups = new Map();

            (Array.isArray(fields) ? fields : []).forEach(field => {
                const sectionId = String(field.sectionId || "custom_fields").trim() || "custom_fields";
                const sectionLabel = String(field.sectionLabel || "Custom Fields").trim() || "Custom Fields";

                if (!groups.has(sectionId)) {
                    const sectionOverride = sectionOverrides[sectionId] || {};
                    groups.set(sectionId, {
                        id: sectionId,
                        label: sectionOverride.label || sectionLabel,
                        order: Number.isFinite(Number(sectionOverride.order)) ? Number(sectionOverride.order) : Number(field.order || 0),
                        archived: Boolean(sectionOverride.archived),
                        archivedAt: this.normalizeDateValue(sectionOverride.archivedAt, null),
                        fields: []
                    });
                }

                const group = groups.get(sectionId);
                group.fields.push(field);
                group.order = Math.min(group.order, Number(field.order || 0));
            });

            return Array.from(groups.values())
                .sort((left, right) => left.order - right.order)
                .map(group => ({
                    ...group,
                    fields: group.fields.sort((left, right) => Number(left.order || 0) - Number(right.order || 0))
                }));
        },

        normalizeFieldValue(field, value) {
            const fieldType = this.getFieldTypeMeta(field?.fieldType).key;

            if (fieldType === "checkbox") {
                return Boolean(value);
            }
            if (fieldType === "number") {
                const parsed = Number(value);
                return Number.isFinite(parsed) ? parsed : "";
            }
            if (fieldType === "multi-select") {
                return Array.isArray(value)
                    ? value.map(item => String(item || "").trim()).filter(Boolean)
                    : String(value || "").split(",").map(item => item.trim()).filter(Boolean);
            }
            if (fieldType === "image") {
                return window.AuthorOSImageAssets
                    ? window.AuthorOSImageAssets.normalizeStoredAsset(value, { maxStoredBytes: 1024 * 1024 }) || null
                    : value && typeof value === "object"
                        ? value
                        : null;
            }

            return value === null || value === undefined ? "" : String(value);
        },

        buildFieldSearchText(fieldValues) {
            if (!fieldValues || typeof fieldValues !== "object") {
                return "";
            }

            return Object.values(fieldValues)
                .flatMap(value => {
                    if (Array.isArray(value)) {
                        return value;
                    }
                    if (value && typeof value === "object") {
                        return value.dataUrl ? [] : Object.values(value);
                    }
                    return [value];
                })
                .map(value => String(value || "").trim())
                .filter(Boolean)
                .join(" ");
        },

        renderLibraryControls(characters) {
            const tags = this.getUniqueTags(characters);
            return `
                <div class="library-controls characters-controls">
                    <div class="library-search">
                        <label for="characters-search-input" class="visually-hidden">Search characters</label>
                        <span class="library-search-icon" aria-hidden="true">⌕</span>
                        <input id="characters-search-input" type="search" class="library-search-input" placeholder="Search characters..." autocomplete="off" value="${this.escapeHTML(this.uiState.search)}" />
                        ${this.uiState.search ? `<button type="button" class="library-search-clear" data-action="clear-character-search" aria-label="Clear search">×</button>` : ""}
                    </div>

                    <div class="library-filter-group">
                        <label for="characters-status-filter">Status</label>
                        <select id="characters-status-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.status === "All" ? "selected" : ""}>All</option>
                            ${STATUS_VALUES.map(value => `<option value="${this.escapeHTML(value)}" ${this.uiState.status === value ? "selected" : ""}>${this.escapeHTML(value)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="characters-role-filter">Role</label>
                        <select id="characters-role-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.role === "All" ? "selected" : ""}>All roles</option>
                            ${ROLE_FILTER_VALUES.map(role => `<option value="${this.escapeHTML(role)}" ${this.uiState.role === role ? "selected" : ""}>${this.escapeHTML(role)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="characters-tag-filter">Tag</label>
                        <select id="characters-tag-filter" class="library-filter-select">
                            <option value="All" ${this.uiState.tag === "All" ? "selected" : ""}>All tags</option>
                            ${tags.map(tag => `<option value="${this.escapeHTML(tag)}" ${this.uiState.tag === tag ? "selected" : ""}>${this.escapeHTML(tag)}</option>`).join("")}
                        </select>
                    </div>

                    <div class="library-filter-group">
                        <label for="characters-sort-filter">Sort</label>
                        <select id="characters-sort-filter" class="library-filter-select">
                            <option value="updated-desc" ${this.uiState.sort === "updated-desc" ? "selected" : ""}>Recently updated</option>
                            <option value="created-desc" ${this.uiState.sort === "created-desc" ? "selected" : ""}>Recently created</option>
                            <option value="name-asc" ${this.uiState.sort === "name-asc" ? "selected" : ""}>Name A-Z</option>
                            <option value="name-desc" ${this.uiState.sort === "name-desc" ? "selected" : ""}>Name Z-A</option>
                            <option value="role" ${this.uiState.sort === "role" ? "selected" : ""}>Role</option>
                        </select>
                    </div>

                    ${this.hasActiveFilters() ? `<button type="button" class="library-clear-filters" data-action="clear-character-filters">Clear filters</button>` : ""}
                </div>
            `;
        },

        getUniqueTags(characters) {
            const tags = [];
            characters.forEach(character => {
                (Array.isArray(character.tags) ? character.tags : []).forEach(tag => {
                    const value = String(tag || "").trim();
                    if (value) {
                        tags.push(value);
                    }
                });
            });
            return [...new Set(tags)].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
        },

        hasActiveFilters() {
            return Boolean(
                this.uiState.search.trim() ||
                this.uiState.status !== "All" ||
                this.uiState.role !== "All" ||
                this.uiState.tag !== "All" ||
                this.uiState.sort !== "updated-desc"
            );
        },

        clearFilters() {
            this.uiState = {
                search: "",
                status: "All",
                role: "All",
                tag: "All",
                sort: "updated-desc"
            };
            this.render(this.container);
        },

        getFilteredCharacters(characters) {
            let filtered = Array.isArray(characters) ? [...characters] : [];

            if (this.uiState.status === "All") {
                filtered = filtered.filter(character => character.status !== "Archived");
            } else {
                filtered = filtered.filter(character => character.status === this.uiState.status);
            }

            if (this.uiState.role !== "All") {
                filtered = filtered.filter(character => this.resolveRoleMeta(character.primaryRoleId || character.role, character.customRoleName || character.role).filterRole === this.uiState.role);
            }

            if (this.uiState.tag !== "All") {
                filtered = filtered.filter(character => Array.isArray(character.tags) && character.tags.includes(this.uiState.tag));
            }

            const search = this.uiState.search.trim().toLowerCase();
            if (search) {
                filtered = filtered.filter(character => this.buildCharacterSearchText(character).includes(search));
            }

            return this.sortCharacters(filtered);
        },

        buildCharacterSearchText(character) {
            const roleMeta = this.resolveRoleMeta(character.primaryRoleId || character.role, character.customRoleName || character.role);
            const dynamicText = this.getResolvedFieldDefinitions(character).map(field => {
                const value = character.fieldValues?.[field.id];
                if (Array.isArray(value)) {
                    return `${field.label} ${value.join(" ")}`;
                }
                if (value && typeof value === "object") {
                    return value.dataUrl ? field.label : `${field.label} ${Object.values(value).join(" ")}`;
                }

                if (this.getFieldTypeMeta(field.fieldType).key === "relationship") {
                    return `${field.label} ${this.resolveEntityTokenLabel(this.getProjectById(character.projectId), value)}`;
                }

                return `${field.label} ${String(value || "")}`;
            }).join(" ");

            return [
                character.name,
                character.displayName,
                character.role,
                roleMeta.filterRole,
                character.status,
                Array.isArray(character.tags) ? character.tags.join(" ") : "",
                character.summary,
                character.description,
                character.notes,
                character.fieldSearchText,
                dynamicText,
                (Array.isArray(character.relationships) ? character.relationships : []).map(relationship => {
                    const targetId = String(relationship.targetCharacterId || relationship.characterId || "").trim();
                    const target = targetId ? this.getCharacter(this.getProjectById(character.projectId), targetId) : null;
                    return `${relationship.relationshipType || ""} ${target ? this.getCharacterName(target) : ""} ${relationship.description || ""}`;
                }).join(" ")
            ]
                .filter(value => value !== null && value !== undefined)
                .join(" ")
                .toLowerCase();
        },

        sortCharacters(characters) {
            const results = [...characters];
            const dateValue = value => {
                const time = Date.parse(value || "");
                return Number.isNaN(time) ? 0 : time;
            };

            switch (this.uiState.sort) {
                case "created-desc":
                    return results.sort((left, right) => dateValue(right.createdAt) - dateValue(left.createdAt));
                case "name-asc":
                    return results.sort((left, right) => this.getCharacterName(left).localeCompare(this.getCharacterName(right), undefined, { sensitivity: "base" }));
                case "name-desc":
                    return results.sort((left, right) => this.getCharacterName(right).localeCompare(this.getCharacterName(left), undefined, { sensitivity: "base" }));
                case "role":
                    return results.sort((left, right) => {
                        const roleResult = String(left.role || "").localeCompare(String(right.role || ""), undefined, { sensitivity: "base" });
                        return roleResult !== 0 ? roleResult : dateValue(right.updatedAt) - dateValue(left.updatedAt);
                    });
                case "updated-desc":
                default:
                    return results.sort((left, right) => dateValue(right.updatedAt) - dateValue(left.updatedAt));
            }
        },

        getCharacterName(character) {
            return String(character?.displayName || character?.name || "Untitled Character").trim() || "Untitled Character";
        },

        renderCharacterGrid(characters) {
            return `<div class="project-grid characters-grid">${characters.map(character => this.renderCharacterCard(character)).join("")}</div>`;
        },

        renderCharacterCard(character) {
            const title = this.escapeHTML(this.getCharacterName(character));
            const role = this.escapeHTML(character.role || "Custom");
            const status = this.escapeHTML(character.status || "Draft");
            const summary = this.escapeHTML(String(character.summary || character.description || "").trim() || "No summary yet.");
            const updated = this.escapeHTML(this.formatDate(character.updatedAt));
            const tags = Array.isArray(character.tags) ? character.tags.slice(0, 5) : [];
            const isSelected = this.selectedCharacterId === character.id;

            return `
                <article class="project-card character-card ${isSelected ? "selected" : ""}">
                    <div class="project-card-body">
                        <header class="character-card-header">
                            <h2>${title}</h2>
                            <p class="character-card-updated">Updated ${updated}</p>
                        </header>
                        <dl class="character-card-meta">
                            <div><dt>Role</dt><dd>${role}</dd></div>
                            <div><dt>Status</dt><dd>${status}</dd></div>
                        </dl>
                        <p class="character-card-summary">${summary}</p>
                        ${tags.length ? `<ul class="idea-tag-list" aria-label="Character tags">${tags.map(tag => `<li>${this.escapeHTML(tag)}</li>`).join("")}</ul>` : ""}
                        <div class="idea-card-actions">
                            <button type="button" class="button button-secondary" data-action="open-character" data-character-id="${this.escapeHTML(character.id)}">Open</button>
                            <button type="button" class="button button-secondary" data-action="edit-character" data-character-id="${this.escapeHTML(character.id)}">Edit</button>
                            <button type="button" class="button button-secondary" data-action="duplicate-character" data-character-id="${this.escapeHTML(character.id)}">Duplicate</button>
                            ${character.status === "Archived"
                                ? `<button type="button" class="button button-secondary" data-action="restore-character" data-character-id="${this.escapeHTML(character.id)}">Restore</button>`
                                : `<button type="button" class="button button-secondary" data-action="archive-character" data-character-id="${this.escapeHTML(character.id)}">Archive</button>`
                            }
                            <button type="button" class="button button-danger" data-action="delete-character" data-character-id="${this.escapeHTML(character.id)}">Delete</button>
                        </div>
                    </div>
                </article>
            `;
        },

        renderEmptyState(hasCharacters) {
            if (hasCharacters) {
                return `
                    <section class="library-empty-state">
                        <div class="empty-state-icon">⌕</div>
                        <h2>No characters match your filters</h2>
                        <p>Adjust search, filters, or sorting.</p>
                        <button type="button" class="button button-secondary" data-action="clear-character-filters">Clear filters</button>
                    </section>
                `;
            }

            return `
                <section class="library-empty-state">
                    <div class="empty-state-icon">♙</div>
                    <h2>No characters yet</h2>
                    <p>Create your first character profile for this project.</p>
                    <button type="button" class="button button-primary" data-action="new-character">Create First Character</button>
                </section>
            `;
        },

        renderDetailEmptyState() {
            return `
                <section class="idea-detail-empty-state">
                    <h3>Select a character</h3>
                    <p>Open a character card to view and manage profile details.</p>
                </section>
            `;
        },

        renderCharacterDetail(character, project) {
            const relationships = this.resolveCharacterRelationships(character, project);
            const sections = this.groupFieldDefinitionsBySection(this.getActiveFieldDefinitions(character), character.sectionOverrides || {});
            const archivedFields = this.getArchivedFieldDefinitions(character);

            return `
                <article class="idea-detail-card character-detail-card">
                    <header class="idea-detail-header">
                        <p class="eyebrow">CHARACTER PROFILE</p>
                        <h2>${this.escapeHTML(this.getCharacterName(character))}</h2>
                        <p class="idea-detail-subtitle">${this.escapeHTML(character.role || "Custom")} | ${this.escapeHTML(character.status || "Draft")}</p>
                    </header>

                    <dl class="idea-detail-meta">
                        <div><dt>Created</dt><dd>${this.escapeHTML(this.formatDate(character.createdAt))}</dd></div>
                        <div><dt>Updated</dt><dd>${this.escapeHTML(this.formatDate(character.updatedAt))}</dd></div>
                    </dl>

                    <section class="idea-detail-section">
                        <h3>Identity</h3>
                        <p><strong>Name:</strong> ${this.escapeHTML(character.name || "Not provided")}</p>
                        <p><strong>Display Name:</strong> ${this.escapeHTML(character.displayName || "Not provided")}</p>
                        <p><strong>Role:</strong> ${this.escapeHTML(character.role || "Custom")}</p>
                        <p><strong>Status:</strong> ${this.escapeHTML(character.status || "Draft")}</p>
                        <p><strong>Tags:</strong> ${Array.isArray(character.tags) && character.tags.length ? this.escapeHTML(character.tags.join(", ")) : "No tags"}</p>
                    </section>

                    ${sections.map(section => this.renderFieldSectionDetail(section, character)).join("")}
                    ${archivedFields.length ? this.renderArchivedFieldSummary(archivedFields) : ""}

                    <section class="idea-detail-section">
                        <h3>Relationships</h3>
                        ${relationships.length
                            ? `<ul class="character-relationship-list">${relationships.map((item, index) => `
                                <li>
                                    <div class="character-relationship-item-main">
                                        <strong>${this.escapeHTML(item.relationshipType || "Other")}</strong>
                                        <p>${this.escapeHTML(item.targetLabel)}</p>
                                        <p>${this.escapeHTML(item.description || "No description.")}</p>
                                    </div>
                                    <div class="character-relationship-item-actions">
                                        <button type="button" class="button button-secondary" data-action="edit-relationship" data-character-id="${this.escapeHTML(character.id)}" data-relationship-index="${index}">Edit</button>
                                        <button type="button" class="button button-danger" data-action="remove-relationship" data-character-id="${this.escapeHTML(character.id)}" data-relationship-index="${index}">Remove</button>
                                    </div>
                                </li>
                            `).join("")}</ul>`
                            : "<p>No relationships added.</p>"
                        }
                        <button type="button" class="button button-secondary" data-action="add-relationship" data-character-id="${this.escapeHTML(character.id)}">Add Relationship</button>
                    </section>

                    <div class="idea-detail-actions">
                        <button type="button" class="button button-secondary" data-action="edit-character" data-character-id="${this.escapeHTML(character.id)}">Edit</button>
                        <button type="button" class="button button-secondary" data-action="duplicate-character" data-character-id="${this.escapeHTML(character.id)}">Duplicate</button>
                        ${character.status === "Archived"
                            ? `<button type="button" class="button button-secondary" data-action="restore-character" data-character-id="${this.escapeHTML(character.id)}">Restore</button>`
                            : `<button type="button" class="button button-secondary" data-action="archive-character" data-character-id="${this.escapeHTML(character.id)}">Archive</button>`
                        }
                        <button type="button" class="button button-danger" data-action="delete-character" data-character-id="${this.escapeHTML(character.id)}">Delete</button>
                    </div>
                </article>
            `;
        },

        renderFieldSectionDetail(section, character) {
            return `
                <section class="idea-detail-section">
                    <h3>${this.escapeHTML(section.label)}</h3>
                    ${section.fields.map(field => this.renderFieldDetailLine(field, character.fieldValues?.[field.id], character)).join("")}
                </section>
            `;
        },

        renderFieldDetailLine(field, value, character) {
            if (this.getFieldTypeMeta(field.fieldType).key === "image" && value?.dataUrl) {
                return `
                    <div class="character-image-detail-block">
                        <strong>${this.escapeHTML(field.label)}:</strong>
                        <div><img src="${this.escapeHTML(value.dataUrl)}" alt="${this.escapeHTML(field.label)}" class="character-field-image-preview" /></div>
                    </div>
                `;
            }

            return `
                <p>
                    <strong>${this.escapeHTML(field.label)}:</strong>
                    ${this.escapeHTML(this.formatFieldValueForDisplay(field, value, character) || "Not provided")}
                </p>
            `;
        },

        formatFieldValueForDisplay(field, value, character) {
            const type = this.getFieldTypeMeta(field.fieldType).key;
            if (type === "checkbox") {
                return value ? "Yes" : "No";
            }
            if (type === "multi-select") {
                return Array.isArray(value) ? value.join(", ") : "";
            }
            if (type === "relationship") {
                return this.resolveEntityTokenLabel(this.getProjectById(character.projectId), value);
            }
            if (type === "image") {
                return value?.dataUrl ? "Image attached" : "";
            }
            return String(value || "").trim();
        },

        renderArchivedFieldSummary(archivedFields) {
            return `
                <section class="idea-detail-section">
                    <h3>Archived Fields</h3>
                    <ul class="character-archived-field-list">
                        ${archivedFields.map(field => `
                            <li>
                                <strong>${this.escapeHTML(field.label)}</strong>
                                <span>${this.escapeHTML(this.getFieldTypeMeta(field.fieldType).label)}</span>
                            </li>
                        `).join("")}
                    </ul>
                </section>
            `;
        },

        resolveCharacterRelationships(character, project) {
            const characters = this.getCharacters(project);
            const lookup = new Map(characters.map(item => [item.id, item]));
            return (Array.isArray(character.relationships) ? character.relationships : []).map(relationship => {
                const targetId = String(relationship.targetCharacterId || relationship.characterId || "").trim();
                const targetCharacter = targetId ? lookup.get(targetId) : null;
                return {
                    ...relationship,
                    targetLabel: targetCharacter
                        ? this.getCharacterName(targetCharacter)
                        : targetId
                            ? "Missing character reference"
                            : "Unlinked relationship"
                };
            });
        },

        bindEvents(container, projectId) {
            container.querySelectorAll('[data-action="new-character"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showCharacterRoleSelectorModal(projectId);
                });
            });

            const searchInput = container.querySelector("#characters-search-input");
            if (searchInput) {
                searchInput.addEventListener("input", () => {
                    this.uiState.search = searchInput.value || "";
                    this.render(this.container);
                });
            }

            container.querySelector('[data-action="clear-character-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.search = "";
                this.render(this.container);
            });

            const statusFilter = container.querySelector("#characters-status-filter");
            const roleFilter = container.querySelector("#characters-role-filter");
            const tagFilter = container.querySelector("#characters-tag-filter");
            const sortFilter = container.querySelector("#characters-sort-filter");

            statusFilter?.addEventListener("change", () => {
                this.uiState.status = statusFilter.value || "All";
                this.render(this.container);
            });
            roleFilter?.addEventListener("change", () => {
                this.uiState.role = roleFilter.value || "All";
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

            container.querySelectorAll('[data-action="clear-character-filters"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.clearFilters();
                });
            });

            ["open-character", "edit-character", "duplicate-character", "archive-character", "restore-character", "delete-character"].forEach(action => {
                container.querySelectorAll(`[data-action="${action}"]`).forEach(button => {
                    button.addEventListener("click", event => {
                        event.preventDefault();
                        const characterId = button.dataset.characterId;
                        if (action === "open-character") {
                            this.openCharacter(projectId, characterId);
                        }
                        if (action === "edit-character") {
                            this.showCharacterFormModal(projectId, characterId);
                        }
                        if (action === "duplicate-character") {
                            this.duplicateCharacter(projectId, characterId);
                        }
                        if (action === "archive-character") {
                            this.archiveCharacter(projectId, characterId);
                        }
                        if (action === "restore-character") {
                            this.restoreCharacter(projectId, characterId);
                        }
                        if (action === "delete-character") {
                            this.confirmDeleteCharacter(projectId, characterId);
                        }
                    });
                });
            });

            container.querySelectorAll('[data-action="add-relationship"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showRelationshipModal(projectId, button.dataset.characterId);
                });
            });

            container.querySelectorAll('[data-action="edit-relationship"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    const index = Number(button.dataset.relationshipIndex);
                    this.showRelationshipModal(projectId, button.dataset.characterId, Number.isFinite(index) ? index : -1);
                });
            });

            container.querySelectorAll('[data-action="remove-relationship"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    const index = Number(button.dataset.relationshipIndex);
                    this.removeRelationship(projectId, button.dataset.characterId, Number.isFinite(index) ? index : -1);
                });
            });
        },

        openCharacter(projectId, characterId) {
            const project = this.getProjectById(projectId);
            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }
            const character = this.getCharacter(project, characterId);
            if (!character) {
                this.core.notify("Character could not be found.", "error");
                return;
            }
            this.selectedCharacterId = character.id;
            this.render(this.container);
        },

        showCharacterRoleSelectorModal(projectId) {
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

            const roles = this.getRoleSelectorCatalog();
            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal character-role-modal" role="dialog" aria-modal="true" aria-labelledby="character-role-selector-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">CHARACTER STUDIO</p>
                                <h2 id="character-role-selector-title">Choose Character Role</h2>
                                <p>Select the role that best matches this character. You can change it later without losing information.</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-character-role-modal" aria-label="Close character role selector">×</button>
                        </header>
                        <div class="character-role-selector-grid">
                            ${roles.map(role => `
                                <button type="button" class="character-role-selector-card" data-action="select-character-role" data-role-id="${this.escapeHTML(role.key)}">
                                    <span class="character-role-selector-title">${this.escapeHTML(role.label)}</span>
                                    <span class="character-role-selector-description">${this.escapeHTML(role.description)}</span>
                                </button>
                            `).join("")}
                        </div>
                        <footer class="project-modal-footer">
                            <button type="button" class="button button-secondary" data-action="close-character-role-modal">Cancel</button>
                        </footer>
                    </section>
                </div>
            `;
            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-character-role-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.modalContainer.querySelectorAll('[data-action="select-character-role"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showCharacterFormModal(projectId, null, String(button.dataset.roleId || "minor").trim() || "minor");
                });
            });

            this.bindModalBackdrop();
        },

        createDefaultCharacterDraft(projectId, preferredRoleId = "minor") {
            const now = new Date().toISOString();
            const roleMeta = this.resolveRoleMeta(preferredRoleId, "");
            return this.normalizeCharacter({
                id: AuthorOSHelpers.generateId("character"),
                projectId,
                name: "",
                displayName: "",
                role: roleMeta.displayRole,
                primaryRoleId: roleMeta.key,
                customRoleName: roleMeta.isCustom ? "" : "",
                templateId: this.getRoleTemplateId(roleMeta.key),
                templateVersion: 1,
                status: "Draft",
                tags: [],
                relationships: [],
                fieldValues: {},
                fieldOverrides: {},
                sectionOverrides: {},
                customFields: [],
                createdAt: now,
                updatedAt: now
            }, projectId);
        },

        showCharacterFormModal(projectId, characterId = null, preferredRoleId = null) {
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

            const editingCharacter = characterId ? this.getCharacter(project, characterId) : null;
            if (characterId && !editingCharacter) {
                this.core.notify("Character could not be found.", "error");
                return;
            }

            this.characterFormState = {
                projectId,
                editingCharacterId: editingCharacter?.id || null,
                draftCharacter: editingCharacter
                    ? this.cloneData(editingCharacter)
                    : this.createDefaultCharacterDraft(projectId, preferredRoleId || "minor"),
                showFieldManager: false,
                creatorDraft: {
                    label: "",
                    fieldType: "text",
                    description: "",
                    defaultValue: "",
                    required: false,
                    visible: true,
                    optionsText: ""
                }
            };

            this.renderCharacterFormModal();
        },

        renderCharacterFormModal() {
            const state = this.characterFormState;
            if (!state || !this.modalContainer) {
                return;
            }

            const character = state.draftCharacter;
            const roleMeta = this.resolveRoleMeta(character.primaryRoleId || character.role, character.customRoleName || character.role);
            const isEditing = Boolean(state.editingCharacterId);
            const sections = this.groupFieldDefinitionsBySection(this.getActiveFieldDefinitions(character), character.sectionOverrides || {});
            const archivedFields = this.getArchivedFieldDefinitions(character);

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal character-form-modal" role="dialog" aria-modal="true" aria-labelledby="character-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">CHARACTER STUDIO</p>
                                <h2 id="character-modal-title">${isEditing ? "Edit Character" : "New Character"}</h2>
                                <p>${isEditing ? "Update this character and manage its template fields." : "Create a role-based character profile with fully customisable fields."}</p>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-character-modal" aria-label="Close character form">×</button>
                        </header>

                        <form id="character-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field form-field-wide" for="character-name-input">
                                    <span>Name *</span>
                                    <input id="character-name-input" name="name" type="text" required autocomplete="off" value="${this.escapeHTML(character.name || "")}" />
                                </label>

                                <label class="form-field" for="character-display-name-input">
                                    <span>Display Name</span>
                                    <input id="character-display-name-input" name="displayName" type="text" autocomplete="off" value="${this.escapeHTML(character.displayName || "")}" />
                                </label>

                                <label class="form-field" for="character-role-select-input">
                                    <span>Primary Role</span>
                                    <select id="character-role-select-input" name="primaryRoleId">
                                        ${CHARACTER_ROLE_CATALOG.map(role => `
                                            <option value="${this.escapeHTML(role.key)}" ${role.key === roleMeta.key ? "selected" : ""}>${this.escapeHTML(role.label)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field character-custom-role-field ${roleMeta.key === "custom" ? "" : "is-hidden"}" for="character-custom-role-input">
                                    <span>Custom Role Label</span>
                                    <input id="character-custom-role-input" name="customRoleName" type="text" autocomplete="off" value="${this.escapeHTML(character.customRoleName || (roleMeta.key === "custom" ? character.role || "" : ""))}" placeholder="Enter a custom role" />
                                </label>

                                <label class="form-field" for="character-status-input">
                                    <span>Status</span>
                                    <select id="character-status-input" name="status">
                                        ${STATUS_VALUES.map(value => `
                                            <option value="${this.escapeHTML(value)}" ${(character.status || "Draft") === value ? "selected" : ""}>${this.escapeHTML(value)}</option>
                                        `).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="character-tags-input">
                                    <span>Tags</span>
                                    <input id="character-tags-input" name="tags" type="text" autocomplete="off" value="${this.escapeHTML(Array.isArray(character.tags) ? character.tags.join(", ") : "")}" />
                                </label>

                                <section class="form-field form-field-wide character-template-toolbar">
                                    <div>
                                        <h3 class="character-template-title">${this.escapeHTML(roleMeta.label)} Template</h3>
                                        <p class="character-template-description">${this.escapeHTML(roleMeta.description)}</p>
                                    </div>
                                    <div class="character-template-toolbar-actions">
                                        <button type="button" class="button button-secondary" data-action="toggle-character-field-manager">${state.showFieldManager ? "Hide Field Manager" : "Manage Fields"}</button>
                                        <button type="button" class="button button-secondary" data-action="open-character-custom-field-creator">+ Add Custom Field</button>
                                    </div>
                                </section>

                                ${sections.map(section => this.renderCharacterTemplateSection(section, character)).join("")}
                                ${archivedFields.length ? this.renderArchivedFieldSummary(archivedFields) : ""}
                                ${this.renderFieldManagerPanel(character, state.showFieldManager)}
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-character-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${isEditing ? "Save Changes" : "Save Character"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");
            this.modalContainer.querySelectorAll('[data-action="close-character-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });
            this.bindModalBackdrop();
            this.bindCharacterFormEvents();
            this.modalContainer.querySelector("#character-name-input")?.focus();
        },

        renderCharacterTemplateSection(section, character) {
            return `
                <section class="form-field form-field-wide character-template-section">
                    <h3 class="character-template-section-title">${this.escapeHTML(section.label)}</h3>
                    <div class="character-template-section-grid">
                        ${section.fields.map(field => this.renderCharacterFieldControl(field, character.fieldValues?.[field.id], character)).join("")}
                    </div>
                </section>
            `;
        },

        renderCharacterFieldControl(field, value, character) {
            const fieldId = String(field.id || "").trim();
            const inputId = `character-field-${fieldId}`;
            const fieldType = this.getFieldTypeMeta(field.fieldType).key;
            const label = this.escapeHTML(field.label);

            if (fieldType === "long-text" || fieldType === "rich-text") {
                return `
                    <label class="form-field form-field-wide" for="${this.escapeHTML(inputId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <textarea id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="${this.escapeHTML(fieldType)}" rows="3">${this.escapeHTML(String(value || ""))}</textarea>
                    </label>
                `;
            }

            if (fieldType === "number") {
                return `
                    <label class="form-field" for="${this.escapeHTML(inputId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <input id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="number" type="number" value="${this.escapeHTML(String(value ?? ""))}" />
                    </label>
                `;
            }

            if (fieldType === "date") {
                return `
                    <label class="form-field" for="${this.escapeHTML(inputId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <input id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="date" type="date" value="${this.escapeHTML(String(value || ""))}" />
                    </label>
                `;
            }

            if (fieldType === "checkbox") {
                return `
                    <label class="settings-checkbox-row character-field-checkbox-row">
                        <input class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="checkbox" type="checkbox" ${value ? "checked" : ""}>
                        <span>${label}${field.required ? " *" : ""}</span>
                    </label>
                `;
            }

            if (fieldType === "select") {
                return `
                    <label class="form-field" for="${this.escapeHTML(inputId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <select id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="select">
                            <option value="">Select an option</option>
                            ${(Array.isArray(field.options) ? field.options : []).map(option => `<option value="${this.escapeHTML(option)}" ${String(value || "") === option ? "selected" : ""}>${this.escapeHTML(option)}</option>`).join("")}
                        </select>
                    </label>
                `;
            }

            if (fieldType === "multi-select") {
                const selectedValues = Array.isArray(value) ? value : [];
                return `
                    <label class="form-field form-field-wide" for="${this.escapeHTML(inputId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <select id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="multi-select" multiple size="4">
                            ${(Array.isArray(field.options) ? field.options : []).map(option => `<option value="${this.escapeHTML(option)}" ${selectedValues.includes(option) ? "selected" : ""}>${this.escapeHTML(option)}</option>`).join("")}
                        </select>
                    </label>
                `;
            }

            if (fieldType === "relationship") {
                const relationValue = String(value || "").trim();
                const splitIndex = relationValue.indexOf(":");
                const relationKind = splitIndex > 0 ? relationValue.slice(0, splitIndex) : "character";
                const relationTargetId = splitIndex > 0 ? relationValue.slice(splitIndex + 1) : "";
                const entityOptions = this.getEntityOptions(this.getProjectById(character.projectId), relationKind);
                return `
                    <div class="form-field form-field-wide character-relationship-field" data-field-id="${this.escapeHTML(fieldId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <div class="character-relationship-field-grid">
                            <select class="character-dynamic-field character-relationship-kind" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="relationship-kind">
                                ${RELATIONSHIP_ENTITY_KINDS.map(kind => `<option value="${this.escapeHTML(kind.key)}" ${kind.key === relationKind ? "selected" : ""}>${this.escapeHTML(kind.label)}</option>`).join("")}
                            </select>
                            <select class="character-dynamic-field character-relationship-target" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="relationship">
                                <option value="">Select a linked entity</option>
                                ${entityOptions.map(option => `<option value="${this.escapeHTML(option.id)}" ${option.id === relationTargetId ? "selected" : ""}>${this.escapeHTML(option.label)}</option>`).join("")}
                            </select>
                        </div>
                    </div>
                `;
            }

            if (fieldType === "url") {
                return `
                    <label class="form-field form-field-wide" for="${this.escapeHTML(inputId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        <input id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="url" type="url" value="${this.escapeHTML(String(value || ""))}" />
                    </label>
                `;
            }

            if (fieldType === "image") {
                const hasImage = Boolean(value?.dataUrl);
                return `
                    <section class="form-field form-field-wide character-image-field" data-field-id="${this.escapeHTML(fieldId)}">
                        <span>${label}${field.required ? " *" : ""}</span>
                        ${hasImage
                            ? `<div class="character-field-image-preview-wrap"><img src="${this.escapeHTML(value.dataUrl)}" alt="${label}" class="character-field-image-preview" /></div>`
                            : `<p class="character-field-image-empty">No image selected.</p>`
                        }
                        <div class="character-image-field-actions">
                            <button type="button" class="button button-secondary" data-action="choose-character-field-image" data-field-id="${this.escapeHTML(fieldId)}">Choose Image</button>
                            <button type="button" class="button button-secondary" data-action="remove-character-field-image" data-field-id="${this.escapeHTML(fieldId)}" ${hasImage ? "" : "disabled"}>Remove</button>
                        </div>
                        <input class="visually-hidden character-image-field-input" data-field-id="${this.escapeHTML(fieldId)}" type="file" accept="image/png,image/jpeg,image/webp,image/gif" />
                    </section>
                `;
            }

            return `
                <label class="form-field" for="${this.escapeHTML(inputId)}">
                    <span>${label}${field.required ? " *" : ""}</span>
                    <input id="${this.escapeHTML(inputId)}" class="character-dynamic-field" data-field-id="${this.escapeHTML(fieldId)}" data-field-type="text" type="text" autocomplete="off" value="${this.escapeHTML(String(value || ""))}" />
                </label>
            `;
        },

        renderArchivedFieldSummary(archivedFields) {
            return `
                <section class="form-field form-field-wide character-archived-field-summary">
                    <h3 class="character-template-section-title">Archived Fields</h3>
                    <ul class="character-archived-field-list">
                        ${archivedFields.map(field => `
                            <li>
                                <strong>${this.escapeHTML(field.label)}</strong>
                                <span>${this.escapeHTML(this.getFieldTypeMeta(field.fieldType).label)}</span>
                            </li>
                        `).join("")}
                    </ul>
                </section>
            `;
        },

        renderFieldManagerPanel(character, expanded) {
            const activeFields = this.getActiveFieldDefinitions(character);
            const archivedFields = this.getArchivedFieldDefinitions(character);
            const activeSections = this.groupFieldDefinitionsBySection(activeFields, character.sectionOverrides || {});
            const archivedSections = this.getArchivedSectionDefinitions(character);
            const draft = this.characterFormState?.creatorDraft || {
                label: "",
                fieldType: "text",
                description: "",
                defaultValue: "",
                required: false,
                visible: true,
                optionsText: ""
            };

            return `
                <section class="form-field form-field-wide character-field-manager ${expanded ? "" : "is-collapsed"}">
                    <h3 class="character-template-section-title">Manage Fields</h3>
                    <p class="character-field-manager-copy">Rename, archive, delete, and reorder fields without destroying unrelated character data.</p>
                    ${expanded ? `
                        <section class="character-section-manager-panel">
                            <h4 class="character-template-section-title">Manage Sections</h4>
                            <div class="character-field-manager-list">
                                ${activeSections.map(section => this.renderSectionManagerRow(section)).join("")}
                            </div>

                            <section class="character-archived-fields-panel">
                                <h4 class="character-template-section-title">Archived Sections</h4>
                                ${archivedSections.length
                                    ? `<div class="character-field-manager-list archived">${archivedSections.map(section => this.renderArchivedSectionManagerRow(section)).join("")}</div>`
                                    : `<p class="character-field-manager-copy">No archived sections.</p>`
                                }
                            </section>
                        </section>

                        <div class="character-field-manager-list">
                            ${activeFields.map(field => this.renderFieldManagerRow(field)).join("")}
                        </div>

                        <section class="character-field-creator-panel">
                            <h4 class="character-template-section-title">Add Custom Field</h4>
                            <div class="character-field-creator-grid">
                                <label class="form-field" for="character-custom-field-label">
                                    <span>Field Name</span>
                                    <input id="character-custom-field-label" name="creatorLabel" type="text" value="${this.escapeHTML(draft.label || "")}" />
                                </label>
                                <label class="form-field" for="character-custom-field-type">
                                    <span>Field Type</span>
                                    <select id="character-custom-field-type" name="creatorFieldType">
                                        ${FIELD_TYPE_CATALOG.map(type => `<option value="${this.escapeHTML(type.key)}" ${type.key === draft.fieldType ? "selected" : ""}>${this.escapeHTML(type.label)}</option>`).join("")}
                                    </select>
                                </label>
                                <label class="form-field form-field-wide" for="character-custom-field-description">
                                    <span>Description</span>
                                    <input id="character-custom-field-description" name="creatorDescription" type="text" value="${this.escapeHTML(draft.description || "")}" />
                                </label>
                                <label class="form-field form-field-wide" for="character-custom-field-default">
                                    <span>Default Value</span>
                                    <input id="character-custom-field-default" name="creatorDefaultValue" type="text" value="${this.escapeHTML(String(draft.defaultValue || ""))}" />
                                </label>
                                <label class="form-field form-field-wide" for="character-custom-field-options">
                                    <span>Options (comma separated where needed)</span>
                                    <input id="character-custom-field-options" name="creatorOptionsText" type="text" value="${this.escapeHTML(draft.optionsText || "")}" />
                                </label>
                                <label class="settings-checkbox-row">
                                    <input type="checkbox" name="creatorRequired" ${draft.required ? "checked" : ""}>
                                    <span>Required</span>
                                </label>
                                <label class="settings-checkbox-row">
                                    <input type="checkbox" name="creatorVisible" ${draft.visible !== false ? "checked" : ""}>
                                    <span>Visible immediately</span>
                                </label>
                            </div>
                            <div class="character-field-manager-inline-actions">
                                <button type="button" class="button button-primary" data-action="save-character-custom-field">Save Custom Field</button>
                            </div>
                        </section>

                        <section class="character-archived-fields-panel">
                            <h4 class="character-template-section-title">Archived Fields</h4>
                            ${archivedFields.length
                                ? `<div class="character-field-manager-list archived">${archivedFields.map(field => this.renderArchivedFieldManagerRow(field)).join("")}</div>`
                                : `<p class="character-field-manager-copy">No archived fields.</p>`
                            }
                        </section>
                    ` : ""}
                </section>
            `;
        },

        renderFieldManagerRow(field) {
            return `
                <div class="character-field-manager-row" data-field-id="${this.escapeHTML(field.id)}">
                    <label class="form-field">
                        <span>Field Name</span>
                        <input class="character-managed-field-label" type="text" value="${this.escapeHTML(field.label)}" />
                    </label>
                    <div class="character-field-manager-meta">
                        <span>${this.escapeHTML(this.getFieldTypeMeta(field.fieldType).label)}</span>
                        <span>${field.isCustom ? "Custom" : "Template"}</span>
                    </div>
                    <label class="settings-checkbox-row">
                        <input class="character-managed-field-required" type="checkbox" ${field.required ? "checked" : ""}>
                        <span>Required</span>
                    </label>
                    <div class="character-field-manager-inline-actions">
                        <button type="button" class="button button-secondary" data-action="move-character-field-up" data-field-id="${this.escapeHTML(field.id)}">Up</button>
                        <button type="button" class="button button-secondary" data-action="move-character-field-down" data-field-id="${this.escapeHTML(field.id)}">Down</button>
                        <button type="button" class="button button-secondary" data-action="archive-character-field" data-field-id="${this.escapeHTML(field.id)}">Archive</button>
                        <button type="button" class="button button-danger" data-action="delete-character-field" data-field-id="${this.escapeHTML(field.id)}">Delete</button>
                    </div>
                </div>
            `;
        },

        renderArchivedFieldManagerRow(field) {
            return `
                <div class="character-field-manager-row archived" data-field-id="${this.escapeHTML(field.id)}">
                    <div class="character-field-manager-meta stacked">
                        <strong>${this.escapeHTML(field.label)}</strong>
                        <span>${this.escapeHTML(this.getFieldTypeMeta(field.fieldType).label)} | ${this.escapeHTML(field.sectionLabel || "Custom Fields")}</span>
                    </div>
                    <div class="character-field-manager-inline-actions">
                        <button type="button" class="button button-secondary" data-action="restore-character-field" data-field-id="${this.escapeHTML(field.id)}">Restore</button>
                        <button type="button" class="button button-danger" data-action="delete-character-field" data-field-id="${this.escapeHTML(field.id)}">Delete</button>
                    </div>
                </div>
            `;
        },

        renderSectionManagerRow(section) {
            return `
                <div class="character-field-manager-row character-section-manager-row" data-section-id="${this.escapeHTML(section.id)}">
                    <label class="form-field">
                        <span>Section Name</span>
                        <input class="character-managed-section-label" type="text" value="${this.escapeHTML(section.label)}" />
                    </label>
                    <div class="character-field-manager-meta">
                        <span>${section.fields.length} field${section.fields.length === 1 ? "" : "s"}</span>
                    </div>
                    <div class="character-field-manager-inline-actions">
                        <button type="button" class="button button-secondary" data-action="move-character-section-up" data-section-id="${this.escapeHTML(section.id)}">Up</button>
                        <button type="button" class="button button-secondary" data-action="move-character-section-down" data-section-id="${this.escapeHTML(section.id)}">Down</button>
                        <button type="button" class="button button-secondary" data-action="archive-character-section" data-section-id="${this.escapeHTML(section.id)}">Archive</button>
                    </div>
                </div>
            `;
        },

        renderArchivedSectionManagerRow(section) {
            return `
                <div class="character-field-manager-row archived" data-section-id="${this.escapeHTML(section.id)}">
                    <div class="character-field-manager-meta stacked">
                        <strong>${this.escapeHTML(section.label)}</strong>
                        <span>${section.fields.length} field${section.fields.length === 1 ? "" : "s"}</span>
                    </div>
                    <div class="character-field-manager-inline-actions">
                        <button type="button" class="button button-secondary" data-action="restore-character-section" data-section-id="${this.escapeHTML(section.id)}">Restore</button>
                    </div>
                </div>
            `;
        },

        bindCharacterFormEvents() {
            const root = this.modalContainer;
            const form = root?.querySelector("#character-form");
            if (!root || !form || !this.characterFormState) {
                return;
            }

            root.querySelector('#character-role-select-input')?.addEventListener("change", event => {
                this.captureCharacterFormState();
                this.characterFormState.draftCharacter = this.changeCharacterRole(this.characterFormState.draftCharacter, String(event.currentTarget.value || "minor").trim() || "minor", "");
                this.renderCharacterFormModal();
            });

            root.querySelector('#character-custom-role-input')?.addEventListener("input", () => {
                this.captureCharacterFormState();
            });

            root.querySelector('[data-action="toggle-character-field-manager"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.captureCharacterFormState();
                this.characterFormState.showFieldManager = !this.characterFormState.showFieldManager;
                this.renderCharacterFormModal();
            });

            root.querySelector('[data-action="open-character-custom-field-creator"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.captureCharacterFormState();
                this.characterFormState.showFieldManager = true;
                this.renderCharacterFormModal();
                this.modalContainer?.querySelector('#character-custom-field-label')?.focus();
            });

            root.querySelector('[data-action="save-character-custom-field"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.captureCharacterFormState();
                this.handleCreateCustomField();
            });

            [
                ["move-character-field-up", -1],
                ["move-character-field-down", 1]
            ].forEach(item => {
                root.querySelectorAll(`[data-action="${item[0]}"]`).forEach(button => {
                    button.addEventListener("click", event => {
                        event.preventDefault();
                        this.captureCharacterFormState();
                        this.moveCharacterField(String(button.dataset.fieldId || ""), item[1]);
                    });
                });
            });

            [
                ["move-character-section-up", -1],
                ["move-character-section-down", 1]
            ].forEach(item => {
                root.querySelectorAll(`[data-action="${item[0]}"]`).forEach(button => {
                    button.addEventListener("click", event => {
                        event.preventDefault();
                        this.captureCharacterFormState();
                        this.moveCharacterSection(String(button.dataset.sectionId || ""), item[1]);
                    });
                });
            });

            root.querySelectorAll('[data-action="archive-character-section"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    this.archiveCharacterSection(String(button.dataset.sectionId || ""));
                });
            });

            root.querySelectorAll('[data-action="restore-character-section"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    this.restoreCharacterSection(String(button.dataset.sectionId || ""));
                });
            });

            root.querySelectorAll('[data-action="archive-character-field"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    this.archiveCharacterField(String(button.dataset.fieldId || ""));
                });
            });

            root.querySelectorAll('[data-action="restore-character-field"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    this.restoreCharacterField(String(button.dataset.fieldId || ""));
                });
            });

            root.querySelectorAll('[data-action="delete-character-field"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    this.deleteCharacterField(String(button.dataset.fieldId || ""));
                });
            });

            root.querySelectorAll('.character-relationship-kind').forEach(select => {
                select.addEventListener("change", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    this.renderCharacterFormModal();
                });
            });

            root.querySelectorAll('[data-action="choose-character-field-image"]').forEach(button => {
                button.addEventListener("click", async event => {
                    event.preventDefault();

                    if (window.AuthorOSDesktop?.isTauri?.()) {

                        const selected = await window.AuthorOSDesktop.openFile({
                            filters: [
                                {
                                    name: "Images",
                                    extensions: ["jpg", "jpeg", "png", "webp", "gif"]
                                }
                            ]
                        });

                        if (selected.canceled || !selected.ok) {

                            if (!selected.canceled && selected.error) {
                                this.core.notify(selected.error, "error");
                            }

                            return;

                        }

                        await this.handleCharacterImageFieldSelection(
                            String(button.dataset.fieldId || ""),
                            selected.file || null
                        );

                        return;

                    }

                    root.querySelector(`.character-image-field-input[data-field-id="${button.dataset.fieldId}"]`)?.click();
                });
            });

            root.querySelectorAll('[data-action="remove-character-field-image"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.captureCharacterFormState();
                    const fieldId = String(button.dataset.fieldId || "").trim();
                    this.characterFormState.draftCharacter.fieldValues[fieldId] = null;
                    this.renderCharacterFormModal();
                });
            });

            root.querySelectorAll('.character-image-field-input').forEach(input => {
                input.addEventListener("change", async event => {
                    const fieldId = String(input.dataset.fieldId || "").trim();
                    const file = event.currentTarget?.files?.[0] || null;
                    await this.handleCharacterImageFieldSelection(fieldId, file);
                    input.value = "";
                });
            });

            form.addEventListener("submit", event => {
                event.preventDefault();
                this.handleCharacterFormSubmit(this.characterFormState.projectId, this.characterFormState.editingCharacterId, event.currentTarget);
            });
        },

        captureCharacterFormState() {
            const state = this.characterFormState;
            const form = this.modalContainer?.querySelector('#character-form');
            if (!state || !form) {
                return;
            }

            const nextDraft = this.cloneData(state.draftCharacter);
            if (!nextDraft) {
                return;
            }

            nextDraft.name = String(form.querySelector('[name="name"]')?.value || nextDraft.name || "").trim();
            nextDraft.displayName = String(form.querySelector('[name="displayName"]')?.value || "").trim();
            nextDraft.status = String(form.querySelector('[name="status"]')?.value || nextDraft.status || "Draft").trim() || "Draft";
            nextDraft.primaryRoleId = String(form.querySelector('[name="primaryRoleId"]')?.value || nextDraft.primaryRoleId || "minor").trim() || "minor";
            nextDraft.customRoleName = String(form.querySelector('[name="customRoleName"]')?.value || nextDraft.customRoleName || "").trim();
            nextDraft.tags = String(form.querySelector('[name="tags"]')?.value || "").split(",").map(tag => tag.trim()).filter(Boolean);
            nextDraft.role = this.resolveRoleMeta(nextDraft.primaryRoleId, nextDraft.customRoleName).displayRole;

            Array.from(form.querySelectorAll('.character-section-manager-row[data-section-id]')).forEach(row => {
                const sectionId = String(row.dataset.sectionId || "").trim();
                if (!sectionId) {
                    return;
                }

                nextDraft.sectionOverrides = nextDraft.sectionOverrides && typeof nextDraft.sectionOverrides === "object"
                    ? nextDraft.sectionOverrides
                    : {};

                nextDraft.sectionOverrides[sectionId] = {
                    ...(nextDraft.sectionOverrides[sectionId] || {}),
                    label: String(row.querySelector('.character-managed-section-label')?.value || "").trim(),
                    archived: Boolean(nextDraft.sectionOverrides[sectionId]?.archived),
                    order: Number.isFinite(Number(nextDraft.sectionOverrides[sectionId]?.order))
                        ? Number(nextDraft.sectionOverrides[sectionId].order)
                        : null,
                    archivedAt: this.normalizeDateValue(nextDraft.sectionOverrides[sectionId]?.archivedAt, null)
                };
            });

            nextDraft.fieldValues = {
                ...(nextDraft.fieldValues || {}),
                ...this.collectDynamicFieldValuesFromForm(form, nextDraft)
            };

            Array.from(form.querySelectorAll('.character-field-manager-row[data-field-id]')).forEach(row => {
                const fieldId = String(row.dataset.fieldId || "").trim();
                if (!fieldId) {
                    return;
                }

                const label = String(row.querySelector('.character-managed-field-label')?.value || "").trim();
                const required = Boolean(row.querySelector('.character-managed-field-required')?.checked);

                nextDraft.fieldOverrides = nextDraft.fieldOverrides && typeof nextDraft.fieldOverrides === "object"
                    ? nextDraft.fieldOverrides
                    : {};
                nextDraft.fieldOverrides[fieldId] = {
                    ...(nextDraft.fieldOverrides[fieldId] || {}),
                    label,
                    required,
                    archived: Boolean(nextDraft.fieldOverrides[fieldId]?.archived),
                    deleted: Boolean(nextDraft.fieldOverrides[fieldId]?.deleted),
                    order: Number.isFinite(Number(nextDraft.fieldOverrides[fieldId]?.order)) ? Number(nextDraft.fieldOverrides[fieldId].order) : null,
                    sectionId: String(nextDraft.fieldOverrides[fieldId]?.sectionId || ""),
                    sectionLabel: String(nextDraft.fieldOverrides[fieldId]?.sectionLabel || ""),
                    description: String(nextDraft.fieldOverrides[fieldId]?.description || ""),
                    archivedAt: this.normalizeDateValue(nextDraft.fieldOverrides[fieldId]?.archivedAt, null)
                };

                const customIndex = Array.isArray(nextDraft.customFields)
                    ? nextDraft.customFields.findIndex(field => field.id === fieldId)
                    : -1;
                if (customIndex >= 0) {
                    nextDraft.customFields[customIndex] = {
                        ...nextDraft.customFields[customIndex],
                        label: label || nextDraft.customFields[customIndex].label,
                        required
                    };
                }
            });

            state.creatorDraft = {
                label: String(form.querySelector('[name="creatorLabel"]')?.value || state.creatorDraft?.label || "").trim(),
                fieldType: String(form.querySelector('[name="creatorFieldType"]')?.value || state.creatorDraft?.fieldType || "text").trim() || "text",
                description: String(form.querySelector('[name="creatorDescription"]')?.value || state.creatorDraft?.description || ""),
                defaultValue: String(form.querySelector('[name="creatorDefaultValue"]')?.value || state.creatorDraft?.defaultValue || ""),
                required: Boolean(form.querySelector('[name="creatorRequired"]')?.checked),
                visible: Boolean(form.querySelector('[name="creatorVisible"]')?.checked),
                optionsText: String(form.querySelector('[name="creatorOptionsText"]')?.value || state.creatorDraft?.optionsText || "")
            };

            state.draftCharacter = nextDraft;
        },

        collectDynamicFieldValuesFromForm(form, draftCharacter) {
            const result = {};

            Array.from(form.querySelectorAll('.character-dynamic-field[data-field-id][data-field-type]')).forEach(element => {
                const fieldId = String(element.dataset.fieldId || "").trim();
                const fieldType = String(element.dataset.fieldType || "text").trim().toLowerCase();

                if (!fieldId || fieldType === "relationship-kind") {
                    return;
                }

                if (fieldType === "checkbox") {
                    result[fieldId] = Boolean(element.checked);
                    return;
                }
                if (fieldType === "number") {
                    const parsed = Number(element.value || "");
                    result[fieldId] = Number.isFinite(parsed) ? parsed : "";
                    return;
                }
                if (fieldType === "multi-select") {
                    result[fieldId] = Array.from(element.selectedOptions || []).map(option => String(option.value || "").trim()).filter(Boolean);
                    return;
                }
                if (fieldType === "relationship") {
                    const kind = String(form.querySelector(`.character-relationship-kind[data-field-id="${fieldId}"]`)?.value || "character").trim();
                    const targetId = String(element.value || "").trim();
                    result[fieldId] = targetId ? `${kind}:${targetId}` : "";
                    return;
                }

                result[fieldId] = String(element.value || "");
            });

            Array.from(form.querySelectorAll('.character-image-field[data-field-id]')).forEach(wrapper => {
                const fieldId = String(wrapper.dataset.fieldId || "").trim();
                if (fieldId && Object.prototype.hasOwnProperty.call(draftCharacter.fieldValues || {}, fieldId)) {
                    result[fieldId] = draftCharacter.fieldValues[fieldId];
                }
            });

            return result;
        },

        changeCharacterRole(character, nextRoleId, customRoleName) {
            const draft = this.cloneData(character);
            if (!draft) {
                return character;
            }

            const currentResolved = this.getResolvedFieldDefinitions(draft);
            const nextBaseIds = new Set(this.getRoleTemplateSections(nextRoleId).flatMap(section => section.fields.map(field => field.id)));
            const existingCustomFields = Array.isArray(draft.customFields) ? [...draft.customFields] : [];
            const existingCustomIds = new Set(existingCustomFields.map(field => field.id));

            currentResolved.forEach(field => {
                if (field.isCustom || field.deleted || nextBaseIds.has(field.id) || existingCustomIds.has(field.id)) {
                    return;
                }
                existingCustomFields.push({
                    id: field.id,
                    label: field.label,
                    fieldType: field.fieldType,
                    description: field.description || "",
                    required: Boolean(field.required),
                    archived: Boolean(field.archived),
                    deleted: false,
                    order: Number(field.order || 0),
                    sectionId: field.sectionId || "custom_fields",
                    sectionLabel: field.sectionLabel || "Custom Fields",
                    options: Array.isArray(field.options) ? [...field.options] : [],
                    defaultValue: field.defaultValue,
                    archivedAt: this.normalizeDateValue(field.archivedAt, null),
                    isCustom: true
                });
                existingCustomIds.add(field.id);
            });

            const roleMeta = this.resolveRoleMeta(nextRoleId, customRoleName);
            draft.primaryRoleId = roleMeta.key;
            draft.customRoleName = roleMeta.isCustom ? String(customRoleName || draft.customRoleName || draft.role || "").trim() : "";
            draft.role = roleMeta.isCustom ? (draft.customRoleName || "Custom") : roleMeta.label;
            draft.templateId = this.getRoleTemplateId(roleMeta.key);
            draft.templateVersion = 1;
            draft.customFields = existingCustomFields;
            draft.fieldValues = { ...(draft.fieldValues || {}) };

            return this.normalizeCharacter(draft, draft.projectId || this.characterFormState?.projectId || this.activeProjectId || "");
        },

        handleCreateCustomField() {
            const state = this.characterFormState;
            if (!state) {
                return;
            }

            const draft = state.creatorDraft || {};
            const label = String(draft.label || "").trim();
            const fieldType = this.getFieldTypeMeta(draft.fieldType).key;

            if (!label) {
                this.core.notify("Custom field name is required.", "error");
                this.modalContainer?.querySelector('#character-custom-field-label')?.focus();
                return;
            }

            const field = {
                id: AuthorOSHelpers.generateId("character_field"),
                label,
                fieldType,
                description: String(draft.description || ""),
                required: Boolean(draft.required),
                archived: draft.visible === false,
                deleted: false,
                order: this.getNextFieldOrder(state.draftCharacter),
                sectionId: "custom_fields",
                sectionLabel: "Custom Fields",
                options: String(draft.optionsText || "").split(",").map(item => item.trim()).filter(Boolean),
                defaultValue: fieldType === "checkbox"
                    ? ["true", "yes", "1", "checked"].includes(String(draft.defaultValue || "").trim().toLowerCase())
                    : fieldType === "multi-select"
                        ? String(draft.defaultValue || "").split(",").map(item => item.trim()).filter(Boolean)
                        : String(draft.defaultValue || ""),
                archivedAt: draft.visible === false ? new Date().toISOString() : null,
                isCustom: true
            };

            state.draftCharacter.customFields = Array.isArray(state.draftCharacter.customFields)
                ? [...state.draftCharacter.customFields, field]
                : [field];
            state.draftCharacter.fieldValues = {
                ...(state.draftCharacter.fieldValues || {}),
                [field.id]: this.normalizeFieldValue(field, field.defaultValue)
            };
            state.creatorDraft = {
                label: "",
                fieldType: "text",
                description: "",
                defaultValue: "",
                required: false,
                visible: true,
                optionsText: ""
            };
            state.showFieldManager = true;
            this.renderCharacterFormModal();
            this.core.notify("Custom field added.", "success");
        },

        getNextFieldOrder(character) {
            return this.getResolvedFieldDefinitions(character).reduce((max, field) => Math.max(max, Number(field.order || 0)), 0) + 1;
        },

        getArchivedSectionDefinitions(character) {
            const overrides = character?.sectionOverrides && typeof character.sectionOverrides === "object"
                ? character.sectionOverrides
                : {};
            const activeDefinitions = this.getResolvedFieldDefinitions(character);
            const activeGroups = this.groupFieldDefinitionsBySection(activeDefinitions, overrides);
            const activeIds = new Set(activeGroups.map(group => group.id));

            return Object.keys(overrides)
                .filter(sectionId => overrides[sectionId]?.archived)
                .map(sectionId => ({
                    id: sectionId,
                    label: String(overrides[sectionId]?.label || sectionId),
                    order: Number(overrides[sectionId]?.order || 0),
                    archived: true,
                    fields: activeDefinitions.filter(field => String(field.sectionId || "") === sectionId)
                }))
                .filter(section => !activeIds.has(section.id))
                .sort((left, right) => Number(left.order || 0) - Number(right.order || 0));
        },

        moveCharacterField(fieldId, direction) {
            const state = this.characterFormState;
            if (!state || !fieldId) {
                return;
            }

            const definitions = this.getActiveFieldDefinitions(state.draftCharacter);
            const index = definitions.findIndex(field => field.id === fieldId);
            if (index === -1) {
                return;
            }
            const swapIndex = index + direction;
            if (swapIndex < 0 || swapIndex >= definitions.length) {
                return;
            }

            const current = definitions[index];
            const target = definitions[swapIndex];
            this.setFieldOrder(state.draftCharacter, current.id, Number(target.order || 0));
            this.setFieldOrder(state.draftCharacter, target.id, Number(current.order || 0));
            this.renderCharacterFormModal();
        },

        moveCharacterSection(sectionId, direction) {
            const state = this.characterFormState;
            if (!state || !sectionId) {
                return;
            }

            const sections = this.groupFieldDefinitionsBySection(this.getActiveFieldDefinitions(state.draftCharacter), state.draftCharacter.sectionOverrides || {});
            const index = sections.findIndex(section => section.id === sectionId);
            if (index === -1) {
                return;
            }

            const swapIndex = index + direction;
            if (swapIndex < 0 || swapIndex >= sections.length) {
                return;
            }

            const current = sections[index];
            const target = sections[swapIndex];
            this.setSectionOrder(state.draftCharacter, current.id, Number(target.order || 0));
            this.setSectionOrder(state.draftCharacter, target.id, Number(current.order || 0));
            this.renderCharacterFormModal();
        },

        setFieldOrder(character, fieldId, nextOrder) {
            const customIndex = Array.isArray(character.customFields)
                ? character.customFields.findIndex(field => field.id === fieldId)
                : -1;

            if (customIndex >= 0) {
                character.customFields[customIndex] = {
                    ...character.customFields[customIndex],
                    order: nextOrder
                };
                return;
            }

            character.fieldOverrides = character.fieldOverrides && typeof character.fieldOverrides === "object" ? character.fieldOverrides : {};
            character.fieldOverrides[fieldId] = {
                ...(character.fieldOverrides[fieldId] || {}),
                order: nextOrder,
                archived: Boolean(character.fieldOverrides[fieldId]?.archived),
                deleted: Boolean(character.fieldOverrides[fieldId]?.deleted),
                label: String(character.fieldOverrides[fieldId]?.label || ""),
                description: String(character.fieldOverrides[fieldId]?.description || ""),
                sectionId: String(character.fieldOverrides[fieldId]?.sectionId || ""),
                sectionLabel: String(character.fieldOverrides[fieldId]?.sectionLabel || ""),
                required: Boolean(character.fieldOverrides[fieldId]?.required),
                archivedAt: this.normalizeDateValue(character.fieldOverrides[fieldId]?.archivedAt, null)
            };
        },

        setSectionOrder(character, sectionId, nextOrder) {
            character.sectionOverrides = character.sectionOverrides && typeof character.sectionOverrides === "object"
                ? character.sectionOverrides
                : {};
            character.sectionOverrides[sectionId] = {
                ...(character.sectionOverrides[sectionId] || {}),
                label: String(character.sectionOverrides[sectionId]?.label || ""),
                archived: Boolean(character.sectionOverrides[sectionId]?.archived),
                order: nextOrder,
                archivedAt: this.normalizeDateValue(character.sectionOverrides[sectionId]?.archivedAt, null)
            };
        },

        archiveCharacterSection(sectionId) {
            const state = this.characterFormState;
            if (!state || !sectionId) {
                return;
            }

            state.draftCharacter.sectionOverrides = state.draftCharacter.sectionOverrides && typeof state.draftCharacter.sectionOverrides === "object"
                ? state.draftCharacter.sectionOverrides
                : {};
            state.draftCharacter.sectionOverrides[sectionId] = {
                ...(state.draftCharacter.sectionOverrides[sectionId] || {}),
                archived: true,
                archivedAt: new Date().toISOString(),
                label: String(state.draftCharacter.sectionOverrides[sectionId]?.label || "")
            };
            this.renderCharacterFormModal();
        },

        restoreCharacterSection(sectionId) {
            const state = this.characterFormState;
            if (!state || !sectionId) {
                return;
            }

            state.draftCharacter.sectionOverrides = state.draftCharacter.sectionOverrides && typeof state.draftCharacter.sectionOverrides === "object"
                ? state.draftCharacter.sectionOverrides
                : {};
            state.draftCharacter.sectionOverrides[sectionId] = {
                ...(state.draftCharacter.sectionOverrides[sectionId] || {}),
                archived: false,
                archivedAt: null,
                label: String(state.draftCharacter.sectionOverrides[sectionId]?.label || "")
            };
            this.renderCharacterFormModal();
        },

        archiveCharacterField(fieldId) {
            const state = this.characterFormState;
            if (!state || !fieldId) {
                return;
            }
            const now = new Date().toISOString();
            const customIndex = Array.isArray(state.draftCharacter.customFields)
                ? state.draftCharacter.customFields.findIndex(field => field.id === fieldId)
                : -1;

            if (customIndex >= 0) {
                state.draftCharacter.customFields[customIndex] = {
                    ...state.draftCharacter.customFields[customIndex],
                    archived: true,
                    archivedAt: now
                };
            } else {
                state.draftCharacter.fieldOverrides = state.draftCharacter.fieldOverrides && typeof state.draftCharacter.fieldOverrides === "object" ? state.draftCharacter.fieldOverrides : {};
                state.draftCharacter.fieldOverrides[fieldId] = {
                    ...(state.draftCharacter.fieldOverrides[fieldId] || {}),
                    archived: true,
                    archivedAt: now
                };
            }
            this.renderCharacterFormModal();
        },

        restoreCharacterField(fieldId) {
            const state = this.characterFormState;
            if (!state || !fieldId) {
                return;
            }
            const customIndex = Array.isArray(state.draftCharacter.customFields)
                ? state.draftCharacter.customFields.findIndex(field => field.id === fieldId)
                : -1;

            if (customIndex >= 0) {
                state.draftCharacter.customFields[customIndex] = {
                    ...state.draftCharacter.customFields[customIndex],
                    archived: false,
                    archivedAt: null
                };
            } else {
                state.draftCharacter.fieldOverrides = state.draftCharacter.fieldOverrides && typeof state.draftCharacter.fieldOverrides === "object" ? state.draftCharacter.fieldOverrides : {};
                state.draftCharacter.fieldOverrides[fieldId] = {
                    ...(state.draftCharacter.fieldOverrides[fieldId] || {}),
                    archived: false,
                    archivedAt: null
                };
            }
            this.renderCharacterFormModal();
        },

        deleteCharacterField(fieldId) {
            const state = this.characterFormState;
            if (!state || !fieldId) {
                return;
            }

            const confirmed = window.confirm("Delete this field? Deleting this field will remove the field and its stored values from this character.");
            if (!confirmed) {
                return;
            }

            const customIndex = Array.isArray(state.draftCharacter.customFields)
                ? state.draftCharacter.customFields.findIndex(field => field.id === fieldId)
                : -1;

            if (customIndex >= 0) {
                state.draftCharacter.customFields.splice(customIndex, 1);
            } else {
                state.draftCharacter.fieldOverrides = state.draftCharacter.fieldOverrides && typeof state.draftCharacter.fieldOverrides === "object" ? state.draftCharacter.fieldOverrides : {};
                state.draftCharacter.fieldOverrides[fieldId] = {
                    ...(state.draftCharacter.fieldOverrides[fieldId] || {}),
                    deleted: true,
                    archived: false,
                    archivedAt: null
                };
            }

            if (state.draftCharacter.fieldValues && Object.prototype.hasOwnProperty.call(state.draftCharacter.fieldValues, fieldId)) {
                delete state.draftCharacter.fieldValues[fieldId];
            }
            this.renderCharacterFormModal();
        },

        async handleCharacterImageFieldSelection(fieldId, file) {
            if (!fieldId || !file || !window.AuthorOSImageAssets || !this.characterFormState?.draftCharacter) {
                return;
            }

            const processed = await window.AuthorOSImageAssets.processFile(file, {
                maxFileBytes: 4 * 1024 * 1024,
                maxWidth: 1200,
                maxHeight: 1200,
                outputType: "image/webp",
                quality: 0.82
            });

            if (!processed.ok) {
                this.core.notify(processed.error || "Unable to use this image. Please choose a supported local image file.", "error");
                return;
            }

            this.characterFormState.draftCharacter.fieldValues = {
                ...(this.characterFormState.draftCharacter.fieldValues || {}),
                [fieldId]: processed.asset
            };
            this.renderCharacterFormModal();
        },

        handleCharacterFormSubmit(projectId, editingCharacterId, form) {
            this.captureCharacterFormState();

            const draft = this.characterFormState?.draftCharacter;
            if (!draft) {
                this.core.notify("Character form state could not be read.", "error");
                return;
            }

            if (!String(draft.name || "").trim()) {
                this.core.notify("Character name is required.", "error");
                form.querySelector('[name="name"]')?.focus();
                return;
            }

            if (!STATUS_VALUES.includes(String(draft.status || "").trim())) {
                this.core.notify("Invalid character status.", "error");
                return;
            }

            const activeFields = this.getActiveFieldDefinitions(draft);
            if (activeFields.some(field => !String(field.label || "").trim())) {
                this.core.notify("Field names cannot be empty.", "error");
                return;
            }

            const seenLabels = new Set();
            const duplicates = activeFields.some(field => {
                const label = String(field.label || "").trim().toLowerCase();
                if (!label) {
                    return false;
                }
                if (seenLabels.has(label)) {
                    return true;
                }
                seenLabels.add(label);
                return false;
            });

            if (duplicates) {
                this.core.notify("Warning: duplicate active field names detected. Rename them to avoid confusion.", "error");
                return;
            }

            const normalizedDraft = this.normalizeCharacter({
                ...draft,
                updatedAt: new Date().toISOString(),
                archivedAt: draft.status === "Archived"
                    ? (draft.archivedAt || new Date().toISOString())
                    : null
            }, projectId);

            if (!normalizedDraft) {
                this.core.notify("Character data is invalid.", "error");
                return;
            }

            if (!editingCharacterId) {
                const created = this.createCharacter(projectId, {
                    ...normalizedDraft,
                    createdAt: normalizedDraft.createdAt || new Date().toISOString(),
                    updatedAt: new Date().toISOString()
                });

                if (!created) {
                    this.core.notify("Unable to save character.", "error");
                    return;
                }

                this.closeModal();
                this.core.notify("Character created.", "success");
                this.render(this.container);
                return;
            }

            const updated = this.updateCharacter(projectId, editingCharacterId, normalizedDraft);

            if (!updated) {
                this.core.notify("Failed to update character.", "error");
                return;
            }

            this.selectedCharacterId = editingCharacterId;
            this.closeModal();
            this.core.notify("Character updated.", "success");
            this.render(this.container);
        },

        createCharacter(projectId, characterPayload) {
            return this.updateProjectCharacters(
                projectId,
                characters => {
                    const normalized = this.normalizeCharacter(characterPayload, projectId);
                    return normalized ? [...characters, normalized] : null;
                },
                "character-create",
                nextCharacters => {
                    this.selectedCharacterId = nextCharacters[nextCharacters.length - 1]?.id || null;
                }
            );
        },

        updateCharacter(projectId, characterId, updates) {
            return this.updateProjectCharacters(
                projectId,
                characters => {
                    const index = characters.findIndex(character => character.id === characterId);
                    if (index === -1) {
                        this.core.notify("Character could not be found.", "error");
                        return null;
                    }

                    const existing = characters[index];
                    const nextCharacter = this.normalizeCharacter({
                        ...existing,
                        ...updates,
                        id: existing.id,
                        projectId: existing.projectId,
                        createdAt: existing.createdAt,
                        relationships: Array.isArray(updates.relationships)
                            ? updates.relationships
                            : Array.isArray(existing.relationships)
                                ? existing.relationships
                                : []
                    }, projectId);

                    if (!nextCharacter) {
                        return null;
                    }

                    const next = [...characters];
                    next[index] = nextCharacter;
                    return next;
                },
                "character-update"
            );
        },

        deleteCharacter(projectId, characterId) {
            return this.updateProjectCharacters(
                projectId,
                characters => {
                    const exists = characters.some(character => character.id === characterId);
                    if (!exists) {
                        return null;
                    }

                    return characters
                        .filter(character => character.id !== characterId)
                        .map(character => ({
                            ...character,
                            relationships: Array.isArray(character.relationships)
                                ? character.relationships.filter(relationship => {
                                    const targetId = String(relationship.targetCharacterId || relationship.characterId || "").trim();
                                    return targetId !== characterId;
                                })
                                : []
                        }));
                },
                "character-delete",
                nextCharacters => {
                    if (this.selectedCharacterId === characterId) {
                        this.selectedCharacterId = nextCharacters[0]?.id || null;
                    }
                }
            );
        },

        duplicateCharacter(projectId, characterId) {
            const project = this.getProjectById(projectId);
            const source = this.getCharacter(project, characterId);

            if (!source) {
                this.core.notify("Character could not be found.", "error");
                return;
            }

            const now = new Date().toISOString();
            const duplicate = {
                ...this.cloneData(source),
                id: AuthorOSHelpers.generateId("character"),
                name: `${source.name} - Copy`,
                displayName: source.displayName ? `${source.displayName} - Copy` : "",
                status: source.status === "Archived" ? "Draft" : source.status,
                archivedAt: null,
                relationships: Array.isArray(source.relationships) ? source.relationships.map(item => ({ ...item })) : [],
                createdAt: now,
                updatedAt: now
            };

            if (!this.createCharacter(projectId, duplicate)) {
                this.core.notify("Failed to duplicate character.", "error");
                return;
            }

            this.core.notify("Character duplicated.", "success");
            this.render(this.container);
        },

        archiveCharacter(projectId, characterId) {
            const now = new Date().toISOString();
            const saved = this.updateCharacter(projectId, characterId, {
                status: "Archived",
                archivedAt: now,
                updatedAt: now
            });

            if (!saved) {
                this.core.notify("Failed to archive character.", "error");
                return;
            }

            this.core.notify("Character archived.", "success");
            this.render(this.container);
        },

        restoreCharacter(projectId, characterId) {
            const now = new Date().toISOString();
            const saved = this.updateCharacter(projectId, characterId, {
                status: "Draft",
                archivedAt: null,
                updatedAt: now
            });

            if (!saved) {
                this.core.notify("Failed to restore character.", "error");
                return;
            }

            this.core.notify("Character restored.", "success");
            this.render(this.container);
        },

        confirmDeleteCharacter(projectId, characterId) {
            const project = this.getProjectById(projectId);
            const character = this.getCharacter(project, characterId);
            if (!character) {
                this.core.notify("Character could not be found.", "error");
                return;
            }
            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete Character",
                content: `
                    <p>Delete \"${this.escapeHTML(this.getCharacterName(character))}\"?</p>
                    <p>This action permanently removes the character profile.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {
                    if (!this.deleteCharacter(projectId, character.id)) {
                        this.core.notify("Failed to delete character.", "error");
                        return;
                    }
                    this.core.notify("Character deleted.", "success");
                    this.render(this.container);
                }
            });
        },

        showRelationshipModal(projectId, characterId, relationshipIndex = -1) {
            const project = this.getProjectById(projectId);
            const character = this.getCharacter(project, characterId);

            if (!project || !character) {
                this.core.notify("Character could not be found.", "error");
                return;
            }

            if (!this.modalContainer) {
                this.modalContainer = document.getElementById("modal-container");
            }
            if (!this.modalContainer) {
                return;
            }

            const currentRelationships = Array.isArray(character.relationships) ? character.relationships : [];
            const editingRelationship = relationshipIndex >= 0 ? currentRelationships[relationshipIndex] || null : null;
            const candidates = this.getCharacters(project).filter(item => item.id !== character.id);

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="relationship-modal-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">CHARACTER RELATIONSHIP</p>
                                <h2 id="relationship-modal-title">${editingRelationship ? "Edit Relationship" : "Add Relationship"}</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-relationship-modal" aria-label="Close relationship form">×</button>
                        </header>

                        <form id="relationship-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field form-field-wide" for="relationship-target-input">
                                    <span>Target Character</span>
                                    <select id="relationship-target-input" name="targetCharacterId" required>
                                        <option value="">Select a character</option>
                                        ${candidates.map(item => `<option value="${this.escapeHTML(item.id)}" ${editingRelationship?.targetCharacterId === item.id || editingRelationship?.characterId === item.id ? "selected" : ""}>${this.escapeHTML(this.getCharacterName(item))}</option>`).join("")}
                                    </select>
                                </label>

                                <label class="form-field" for="relationship-type-input">
                                    <span>Relationship Type</span>
                                    <input id="relationship-type-input" name="relationshipType" type="text" autocomplete="off" value="${this.escapeHTML(editingRelationship?.relationshipType || "ally")}" />
                                </label>

                                <label class="form-field form-field-wide" for="relationship-description-input">
                                    <span>Description</span>
                                    <textarea id="relationship-description-input" name="description" rows="3">${this.escapeHTML(editingRelationship?.description || "")}</textarea>
                                </label>
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-relationship-modal">Cancel</button>
                                <button type="submit" class="button button-primary">${editingRelationship ? "Save Relationship" : "Add Relationship"}</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");
            this.modalContainer.querySelectorAll('[data-action="close-relationship-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });
            this.bindModalBackdrop();
            this.modalContainer.querySelector("#relationship-form")?.addEventListener("submit", event => {
                event.preventDefault();
                this.handleRelationshipSubmit(projectId, character.id, relationshipIndex, event.currentTarget);
            });
        },

        handleRelationshipSubmit(projectId, characterId, relationshipIndex, form) {
            const formData = new FormData(form);
            const targetCharacterId = String(formData.get("targetCharacterId") || "").trim();
            const relationshipType = String(formData.get("relationshipType") || "Other").trim() || "Other";
            const description = String(formData.get("description") || "");

            if (!targetCharacterId) {
                this.core.notify("Select a target character.", "error");
                form.querySelector('[name="targetCharacterId"]')?.focus();
                return;
            }

            const project = this.getProjectById(projectId);
            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const target = this.getCharacter(project, targetCharacterId);
            if (!target || target.projectId !== projectId) {
                this.core.notify("Invalid relationship target.", "error");
                return;
            }
            if (target.id === characterId) {
                this.core.notify("A character cannot target itself.", "error");
                return;
            }

            const saved = this.updateProjectCharacters(
                projectId,
                characters => {
                    const index = characters.findIndex(character => character.id === characterId);
                    if (index === -1) {
                        return null;
                    }

                    const sourceCharacter = characters[index];
                    const existingRelationships = Array.isArray(sourceCharacter.relationships)
                        ? [...sourceCharacter.relationships]
                        : [];

                    const nextRelationship = {
                        characterId: target.id,
                        targetCharacterId: target.id,
                        relationshipType,
                        description,
                        projectId
                    };

                    if (relationshipIndex >= 0 && relationshipIndex < existingRelationships.length) {
                        existingRelationships[relationshipIndex] = nextRelationship;
                    } else {
                        existingRelationships.push(nextRelationship);
                    }

                    const normalized = this.normalizeCharacter({
                        ...sourceCharacter,
                        relationships: existingRelationships,
                        updatedAt: new Date().toISOString()
                    }, projectId);

                    if (!normalized) {
                        return null;
                    }

                    const nextCharacters = [...characters];
                    nextCharacters[index] = normalized;
                    return nextCharacters;
                },
                "character-relationship-save"
            );

            if (!saved) {
                this.core.notify("Failed to save relationship.", "error");
                return;
            }

            this.closeModal();
            this.selectedCharacterId = characterId;
            this.core.notify(relationshipIndex >= 0 ? "Relationship updated." : "Relationship added.", "success");
            this.render(this.container);
        },

        removeRelationship(projectId, characterId, relationshipIndex) {
            const saved = this.updateProjectCharacters(
                projectId,
                characters => {
                    const index = characters.findIndex(character => character.id === characterId);
                    if (index === -1) {
                        return null;
                    }

                    const sourceCharacter = characters[index];
                    const existing = Array.isArray(sourceCharacter.relationships) ? [...sourceCharacter.relationships] : [];
                    if (relationshipIndex < 0 || relationshipIndex >= existing.length) {
                        return null;
                    }

                    existing.splice(relationshipIndex, 1);

                    const nextCharacter = this.normalizeCharacter({
                        ...sourceCharacter,
                        relationships: existing,
                        updatedAt: new Date().toISOString()
                    }, projectId);

                    if (!nextCharacter) {
                        return null;
                    }

                    const nextCharacters = [...characters];
                    nextCharacters[index] = nextCharacter;
                    return nextCharacters;
                },
                "character-relationship-remove"
            );

            if (!saved) {
                this.core.notify("Failed to remove relationship.", "error");
                return;
            }

            this.selectedCharacterId = characterId;
            this.core.notify("Relationship removed.", "success");
            this.render(this.container);
        },

        updateProjectCharacters(projectId, updater, source, onSuccess) {
            const project = this.getProjectById(projectId);
            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return false;
            }

            const hydrated = this.ensureProjectCharacterShape(project);
            const nextProject = this.cloneData(hydrated.project);
            if (!nextProject) {
                return false;
            }

            const currentCharacters = this.getCharacters(nextProject);
            const nextCharacters = updater(currentCharacters);
            if (!Array.isArray(nextCharacters)) {
                return false;
            }

            const now = new Date().toISOString();
            nextProject.story.characters = nextCharacters;
            nextProject.statistics = {
                ...(nextProject.statistics || {}),
                characters: nextCharacters.filter(character => character.status !== "Archived").length
            };
            nextProject.updatedAt = now;
            nextProject.lastModified = now;

            if (!this.persistProject(nextProject, source || "characters-update")) {
                return false;
            }

            if (typeof onSuccess === "function") {
                onSuccess(nextCharacters);
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
                const saved = projectsModule.saveProjects(next, { source: source || "characters" });
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

        getCharacterSummaryCounts(projectId = null) {
            const targetProject = projectId ? this.getProjectById(projectId) : this.getActiveProject();
            if (!targetProject) {
                return { total: 0, active: 0, archived: 0, byRole: {} };
            }

            const characters = this.getCharacters(targetProject);
            const byRole = {};
            characters.forEach(character => {
                const role = this.resolveRoleMeta(character.primaryRoleId || character.role, character.customRoleName || character.role).filterRole;
                byRole[role] = (byRole[role] || 0) + 1;
            });

            return {
                total: characters.length,
                active: characters.filter(character => character.status !== "Archived").length,
                archived: characters.filter(character => character.status === "Archived").length,
                byRole
            };
        },

        getEntityOptions(project, kind) {
            if (!project) {
                return [];
            }

            const normalizedKind = String(kind || "character").trim();

            if (normalizedKind === "project") {
                return [{ id: project.id, label: this.getProjectTitle(project) }];
            }
            if (normalizedKind === "character") {
                return this.getCharacters(project).map(item => ({ id: item.id, label: this.getCharacterName(item) }));
            }
            if (normalizedKind === "world") {
                const worldEntries = Array.isArray(project?.story?.worldEntries) ? project.story.worldEntries : [];
                return worldEntries.map(item => ({ id: item.id, label: String(item.title || item.name || "World Entry") }));
            }
            if (normalizedKind === "chapter") {
                const chapters = Array.isArray(project?.manuscript?.chapters) ? project.manuscript.chapters : [];
                return chapters.map(item => ({ id: item.id, label: String(item.title || "Chapter") }));
            }
            if (normalizedKind === "plotScene") {
                const scenes = Array.isArray(project?.story?.plot?.scenes) ? project.story.plot.scenes : [];
                return scenes.map(item => ({ id: item.id, label: String(item.title || "Scene") }));
            }
            if (normalizedKind === "timelineEvent") {
                const events = Array.isArray(project?.story?.timeline?.events)
                    ? project.story.timeline.events
                    : Array.isArray(project?.story?.timeline)
                        ? project.story.timeline
                        : [];
                return events.map(item => ({ id: item.id, label: String(item.title || item.name || "Event") }));
            }

            return [];
        },

        resolveEntityTokenLabel(project, token) {
            const raw = String(token || "").trim();
            if (!raw || !raw.includes(":")) {
                return raw;
            }
            const splitIndex = raw.indexOf(":");
            const kind = raw.slice(0, splitIndex);
            const id = raw.slice(splitIndex + 1);
            const option = this.getEntityOptions(project, kind).find(item => item.id === id);
            return option
                ? `${RELATIONSHIP_ENTITY_KINDS.find(item => item.key === kind)?.label || kind}: ${option.label}`
                : `${kind}: ${id}`;
        },

        isAllowedStatus(status) {
            return STATUS_VALUES.includes(String(status || "").trim());
        },

        normalizeDateValue(value, fallback) {
            if (value === null || value === undefined || value === "") {
                return fallback;
            }
            const date = new Date(value);
            return Number.isNaN(date.getTime()) ? fallback : date.toISOString();
        },

        formatDate(value) {
            if (!value) {
                return "Unavailable";
            }
            const parsed = new Date(value);
            return Number.isNaN(parsed.getTime()) ? "Unavailable" : parsed.toLocaleString();
        },

        closeModal() {
            if (!this.modalContainer) {
                return;
            }
            this.modalContainer.classList.remove("active");
            this.modalContainer.innerHTML = "";
            this.characterFormState = null;
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
                console.error("Character clone failed:", error);
                return null;
            }
        },

        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
