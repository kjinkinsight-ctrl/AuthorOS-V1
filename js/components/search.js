/*
=========================================================
AUTHOROS
UNIVERSAL SEARCH SERVICE
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSSearch {

        constructor(core) {
            this.core = core;

            this.indexCache = {
                signature: null,
                entries: []
            };

            this.maxRecent = 10;
            this.recentSearchStorageKey = "authoros_recent_searches";

            this.priorityWeights = {
                titleExact: 1000,
                titleStarts: 850,
                titleContains: 700,
                metadataExact: 560,
                metadataStarts: 500,
                metadataContains: 440,
                contentExact: 380,
                contentStarts: 320,
                contentContains: 260,
                tokenBonus: 26
            };
        }


        search(query) {
            const report = this.searchUniversal(query);
            return report.results;
        }


        searchUniversal(rawQuery, options = {}) {

            const normalized = this.normalizeQuery(rawQuery);

            const scope = this.normalizeScope(options.scope);
            const sort = this.normalizeSort(options.sort);

            const includeArchived = Boolean(options.includeArchived);

            const filters = {
                type: String(options.type || "All").trim() || "All",
                projectId: String(options.projectId || "All").trim() || "All",
                series: String(options.series || "All").trim() || "All",
                status: String(options.status || "All").trim() || "All",
                category: String(options.category || "All").trim() || "All",
                tag: String(options.tag || "All").trim() || "All"
            };

            const entries = this.getScopedEntries(
                this.ensureIndex(),
                scope,
                this.getCurrentProjectId()
            );

            const filteredByMeta = entries.filter(entry => this.matchesMetadataFilters(entry, filters, includeArchived));

            const facets = this.buildFacets(entries, includeArchived);

            if (!normalized.canonical) {
                return {
                    query: normalized,
                    scope,
                    sort,
                    includeArchived,
                    filters,
                    facets,
                    emptyQuery: true,
                    total: 0,
                    results: []
                };
            }

            const scored = filteredByMeta
                .map(entry => this.scoreEntry(entry, normalized))
                .filter(item => item.score > 0)
                .map(item => this.toResult(item, normalized));

            const results = this.sortResults(scored, sort);

            return {
                query: normalized,
                scope,
                sort,
                includeArchived,
                filters,
                facets,
                emptyQuery: false,
                total: results.length,
                results
            };

        }


        normalizeScope(scope) {

            const value = String(scope || "all-projects").trim();
            const allowed = ["all-projects", "current-project", "current-series"];

            return allowed.includes(value)
                ? value
                : "all-projects";

        }


        normalizeSort(sort) {

            const value = String(sort || "relevance").trim();
            const allowed = ["relevance", "updated-desc", "created-desc", "alpha"];

            return allowed.includes(value)
                ? value
                : "relevance";

        }


        normalizeQuery(query) {

            const raw = String(query ?? "");
            const trimmed = raw.trim();
            const collapsed = trimmed.replace(/\s+/g, " ");

            const canonical = this.normalizeText(collapsed);
            const tokens = canonical
                ? canonical.split(" ").filter(Boolean)
                : [];

            return {
                raw,
                trimmed,
                collapsed,
                canonical,
                tokens
            };

        }


        normalizeText(value) {

            return String(value || "")
                .toLowerCase()
                .replace(/[^a-z0-9\s]/g, " ")
                .replace(/\s+/g, " ")
                .trim();

        }


        ensureIndex() {

            const signature = this.getIndexSignature();

            if (this.indexCache.signature === signature && Array.isArray(this.indexCache.entries)) {
                return this.indexCache.entries;
            }

            const entries = this.buildIndexEntries();

            this.indexCache.signature = signature;
            this.indexCache.entries = entries;

            return entries;

        }


        rebuildIndex() {

            this.indexCache.signature = null;
            this.indexCache.entries = [];
            return this.ensureIndex();

        }


        getIndexSignature() {

            const projects = this.getProjects();
            const ideas = this.getIdeas();

            const projectSignature = projects
                .map(project => `${project.id || ""}:${project.updatedAt || project.lastModified || ""}:${project.lastOpened || ""}`)
                .join("|");

            const ideaSignature = ideas
                .map(idea => `${idea.id || ""}:${idea.updatedAt || ""}`)
                .join("|");

            return `${projectSignature}::${ideaSignature}`;

        }


        buildIndexEntries() {

            const entries = [];
            const projects = this.getProjects();
            const seriesMap = new Map();

            projects.forEach(project => {

                if (!project || typeof project !== "object" || !project.id) {
                    return;
                }

                const projectName = String(project.name || project.title || "Untitled Project").trim() || "Untitled Project";
                const seriesName = String(project.series || "").trim();
                const genreTags = Array.isArray(project.genreTags)
                    ? project.genreTags.map(tag => String(tag || "").trim()).filter(Boolean)
                    : (String(project.genre || "").trim() ? [String(project.genre || "").trim()] : []);

                entries.push(this.makeEntry({
                    id: project.id,
                    entityType: "Project",
                    route: "project-workspace",
                    projectId: project.id,
                    projectName,
                    series: seriesName,
                    title: projectName,
                    previewText: String(project.description || ""),
                    searchable: {
                        title: projectName,
                        metadata: [project.author, project.genre, ...genreTags, project.type, project.status, seriesName],
                        content: [project.description]
                    },
                    metadata: {
                        status: String(project.status || ""),
                        category: String(project.type || ""),
                        tags: this.stringList(project.tags),
                        priority: ""
                    },
                    createdAt: project.createdAt,
                    updatedAt: project.updatedAt || project.lastModified,
                    archived: String(project.status || "").toLowerCase() === "archived"
                }));

                if (seriesName) {
                    if (!seriesMap.has(seriesName)) {
                        seriesMap.set(seriesName, {
                            name: seriesName,
                            projectIds: []
                        });
                    }

                    seriesMap.get(seriesName).projectIds.push(project.id);
                }

                entries.push(this.makeEntry({
                    id: `manuscript:${project.id}`,
                    entityType: "Manuscript",
                    route: "manuscript",
                    projectId: project.id,
                    projectName,
                    series: seriesName,
                    title: `${projectName} Manuscript`,
                    previewText: `${this.getProjectChapters(project).length} chapters`,
                    searchable: {
                        title: `${projectName} manuscript`,
                        metadata: [seriesName, project.genre, ...genreTags, project.status],
                        content: []
                    },
                    metadata: {
                        status: String(project.status || ""),
                        category: "Manuscript",
                        tags: []
                    },
                    createdAt: project.createdAt,
                    updatedAt: project.updatedAt || project.lastModified,
                    archived: String(project.status || "").toLowerCase() === "archived"
                }));

                this.getProjectChapters(project).forEach(chapter => {
                    entries.push(this.makeEntry({
                        id: chapter.id,
                        entityType: "Chapter",
                        route: "manuscript",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(chapter.title || "Untitled Chapter"),
                        previewText: String(chapter.content || ""),
                        searchable: {
                            title: chapter.title,
                            metadata: [projectName, seriesName, chapter.order, chapter.wordCount],
                            content: [chapter.content]
                        },
                        metadata: {
                            status: "",
                            category: "Manuscript",
                            tags: []
                        },
                        createdAt: chapter.createdAt,
                        updatedAt: chapter.updatedAt,
                        archived: false,
                        nav: {
                            chapterId: chapter.id
                        }
                    }));
                });

                this.getProjectCharacters(project).forEach(character => {
                    entries.push(this.makeEntry({
                        id: character.id,
                        entityType: "Character",
                        route: "characters",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(character.displayName || character.name || "Unnamed Character"),
                        previewText: [character.summary, character.description].filter(Boolean).join(" "),
                        searchable: {
                            title: [character.displayName, character.name],
                            metadata: [character.role, character.status, ...(character.tags || [])],
                            content: [
                                character.summary,
                                character.description,
                                character.appearance,
                                character.personality,
                                character.background,
                                character.goals,
                                character.motivations,
                                character.fears,
                                character.strengths,
                                character.weaknesses,
                                character.notes,
                                character.fieldSearchText
                            ]
                        },
                        metadata: {
                            status: String(character.status || ""),
                            category: String(character.role || ""),
                            tags: this.stringList(character.tags),
                            priority: ""
                        },
                        createdAt: character.createdAt,
                        updatedAt: character.updatedAt,
                        archived: String(character.status || "").toLowerCase() === "archived" || Boolean(character.archivedAt),
                        nav: {
                            characterId: character.id
                        }
                    }));
                });

                this.getProjectWorldEntries(project).forEach(entry => {
                    const worldType = String(entry.type || "World Entry").trim() || "World Entry";

                    entries.push(this.makeEntry({
                        id: entry.id,
                        entityType: worldType,
                        route: "world",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(entry.title || "Untitled World Entry"),
                        previewText: [entry.summary, entry.description].filter(Boolean).join(" "),
                        searchable: {
                            title: entry.title,
                            metadata: [worldType, entry.status, ...(entry.tags || [])],
                            content: [
                                entry.summary,
                                entry.description,
                                entry.notes,
                                entry.region,
                                entry.climate,
                                entry.population,
                                entry.government,
                                entry.landmarks,
                                entry.atmosphere,
                                entry.purpose,
                                entry.leader,
                                entry.members,
                                entry.territory,
                                entry.beliefs,
                                entry.resources,
                                entry.enemies,
                                entry.allies,
                                entry.customs,
                                entry.traditions,
                                entry.language,
                                entry.socialStructure,
                                entry.values,
                                entry.source,
                                entry.rules,
                                entry.limitations,
                                entry.costs,
                                entry.users,
                                entry.effects,
                                entry.risks,
                                entry.origin,
                                entry.owner,
                                entry.material,
                                entry.powers,
                                entry.history,
                                entry.historicalPeriod,
                                entry.significance,
                                entry.relatedEvents,
                                entry.knownVersions
                            ]
                        },
                        metadata: {
                            status: String(entry.status || ""),
                            category: worldType,
                            tags: this.stringList(entry.tags),
                            priority: ""
                        },
                        createdAt: entry.createdAt,
                        updatedAt: entry.updatedAt,
                        archived: String(entry.status || "").toLowerCase() === "archived" || Boolean(entry.archivedAt),
                        nav: {
                            worldEntryId: entry.id
                        }
                    }));
                });

                const plot = this.getProjectPlot(project);

                plot.arcs.forEach(arc => {
                    entries.push(this.makeEntry({
                        id: arc.id,
                        entityType: "Plot Arc",
                        route: "plot",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(arc.title || "Untitled Arc"),
                        previewText: [arc.summary, arc.purpose, arc.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: arc.title,
                            metadata: [arc.status],
                            content: [arc.summary, arc.purpose, arc.notes, arc.beginning, arc.midpoint, arc.ending]
                        },
                        metadata: {
                            status: String(arc.status || ""),
                            category: "Arc",
                            tags: [],
                            priority: ""
                        },
                        createdAt: arc.createdAt,
                        updatedAt: arc.updatedAt,
                        archived: String(arc.status || "").toLowerCase() === "archived" || Boolean(arc.archivedAt),
                        nav: {
                            plotType: "Arc",
                            plotId: arc.id
                        }
                    }));
                });

                plot.acts.forEach(act => {
                    entries.push(this.makeEntry({
                        id: act.id,
                        entityType: "Plot Act",
                        route: "plot",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(act.title || "Untitled Act"),
                        previewText: [act.summary, act.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: act.title,
                            metadata: [],
                            content: [act.summary, act.notes]
                        },
                        metadata: {
                            status: "",
                            category: "Act",
                            tags: [],
                            priority: ""
                        },
                        createdAt: act.createdAt,
                        updatedAt: act.updatedAt,
                        archived: false,
                        nav: {
                            plotType: "Act",
                            plotId: act.id
                        }
                    }));
                });

                plot.beats.forEach(beat => {
                    entries.push(this.makeEntry({
                        id: beat.id,
                        entityType: "Plot Beat",
                        route: "plot",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(beat.title || "Untitled Beat"),
                        previewText: [beat.description, beat.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: beat.title,
                            metadata: [beat.status, beat.type],
                            content: [beat.description, beat.notes]
                        },
                        metadata: {
                            status: String(beat.status || ""),
                            category: String(beat.type || "Beat"),
                            tags: [],
                            priority: ""
                        },
                        createdAt: beat.createdAt,
                        updatedAt: beat.updatedAt,
                        archived: String(beat.status || "").toLowerCase() === "archived" || Boolean(beat.archivedAt),
                        nav: {
                            plotType: "Beat",
                            plotId: beat.id
                        }
                    }));
                });

                plot.threads.forEach(thread => {
                    entries.push(this.makeEntry({
                        id: thread.id,
                        entityType: "Plot Thread",
                        route: "plot",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(thread.title || "Untitled Thread"),
                        previewText: [thread.summary, thread.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: thread.title,
                            metadata: [thread.status, thread.type],
                            content: [thread.summary, thread.notes]
                        },
                        metadata: {
                            status: String(thread.status || ""),
                            category: String(thread.type || "Thread"),
                            tags: [],
                            priority: ""
                        },
                        createdAt: thread.createdAt,
                        updatedAt: thread.updatedAt,
                        archived: String(thread.status || "").toLowerCase() === "archived" || Boolean(thread.archivedAt),
                        nav: {
                            plotType: "Thread",
                            plotId: thread.id
                        }
                    }));
                });

                plot.scenes.forEach(scene => {
                    entries.push(this.makeEntry({
                        id: scene.id,
                        entityType: "Plot Scene",
                        route: "plot",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(scene.title || "Untitled Scene"),
                        previewText: [scene.summary, scene.goal, scene.conflict, scene.outcome, scene.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: scene.title,
                            metadata: [scene.status, scene.time],
                            content: [scene.summary, scene.goal, scene.conflict, scene.outcome, scene.notes]
                        },
                        metadata: {
                            status: String(scene.status || ""),
                            category: "Scene",
                            tags: [],
                            priority: ""
                        },
                        createdAt: scene.createdAt,
                        updatedAt: scene.updatedAt,
                        archived: String(scene.status || "").toLowerCase() === "archived" || Boolean(scene.archivedAt),
                        nav: {
                            plotType: "Scene",
                            plotId: scene.id
                        }
                    }));
                });

                const timeline = this.getProjectTimeline(project);

                timeline.events.forEach(event => {
                    entries.push(this.makeEntry({
                        id: event.id,
                        entityType: "Timeline Event",
                        route: "timeline",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(event.title || "Untitled Event"),
                        previewText: [event.description, event.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: event.title,
                            metadata: [event.status, event.importance, event.type, event.dateLabel, event.dateValue, event.datePrecision],
                            content: [event.description, event.notes]
                        },
                        metadata: {
                            status: String(event.status || ""),
                            category: String(event.type || "Timeline"),
                            tags: [],
                            priority: String(event.importance || "")
                        },
                        createdAt: event.createdAt,
                        updatedAt: event.updatedAt,
                        archived: String(event.status || "").toLowerCase() === "archived" || Boolean(event.archivedAt),
                        nav: {
                            timelineType: "Event",
                            timelineId: event.id
                        }
                    }));
                });

                const notesStudio = this.getProjectNotesStudio(project);

                notesStudio.records.forEach(record => {

                    const recordType = String(record.type || "Note").trim() || "Note";

                    entries.push(this.makeEntry({
                        id: record.id,
                        entityType: recordType,
                        route: "notes",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(record.title || `Untitled ${recordType}`),
                        previewText: [record.summary, record.content].filter(Boolean).join(" "),
                        searchable: {
                            title: record.title,
                            metadata: [recordType, record.status, record.priority, record.category, ...(record.tags || [])],
                            content: [record.summary, record.content]
                        },
                        metadata: {
                            status: String(record.status || ""),
                            category: String(record.category || ""),
                            tags: this.stringList(record.tags),
                            priority: String(record.priority || "")
                        },
                        createdAt: record.createdAt,
                        updatedAt: record.updatedAt,
                        archived: String(record.status || "").toLowerCase() === "archived" || Boolean(record.archivedAt),
                        nav: {
                            notesKind: "record",
                            notesId: record.id
                        }
                    }));
                });

                notesStudio.sources.forEach(source => {
                    entries.push(this.makeEntry({
                        id: source.id,
                        entityType: "Source",
                        route: "notes",
                        projectId: project.id,
                        projectName,
                        series: seriesName,
                        title: String(source.title || "Untitled Source"),
                        previewText: [source.description, source.citation, source.notes].filter(Boolean).join(" "),
                        searchable: {
                            title: source.title,
                            metadata: [source.sourceType, source.author, source.publisher, source.publicationDate, source.url],
                            content: [source.description, source.citation, source.notes]
                        },
                        metadata: {
                            status: source.archivedAt ? "Archived" : "Active",
                            category: String(source.sourceType || ""),
                            tags: [],
                            priority: ""
                        },
                        createdAt: source.createdAt,
                        updatedAt: source.updatedAt,
                        archived: Boolean(source.archivedAt),
                        nav: {
                            notesKind: "source",
                            notesId: source.id
                        }
                    }));
                });

            });

            this.getIdeas().forEach(idea => {

                if (!idea || typeof idea !== "object" || !idea.id) {
                    return;
                }

                const linkedProject = idea.convertedProjectId
                    ? projects.find(project => project.id === idea.convertedProjectId) || null
                    : null;

                entries.push(this.makeEntry({
                    id: idea.id,
                    entityType: "Idea",
                    route: "ideas",
                    projectId: linkedProject?.id || "",
                    projectName: linkedProject ? String(linkedProject.name || linkedProject.title || "") : "",
                    series: linkedProject ? String(linkedProject.series || "") : "",
                    title: String(idea.title || "Untitled Idea"),
                    previewText: [idea.concept, idea.synopsis, idea.notes].filter(Boolean).join(" "),
                    searchable: {
                        title: idea.title,
                        metadata: [idea.status, idea.priority, idea.genre, ...(idea.tags || [])],
                        content: [idea.concept, idea.synopsis, idea.notes]
                    },
                    metadata: {
                        status: String(idea.status || ""),
                        category: String(idea.genre || ""),
                        tags: this.stringList(idea.tags),
                        priority: String(idea.priority || "")
                    },
                    createdAt: idea.createdAt,
                    updatedAt: idea.updatedAt,
                    archived: String(idea.status || "").toLowerCase() === "archived" || Boolean(idea.archivedAt),
                    nav: {
                        ideaId: idea.id
                    }
                }));

            });

            seriesMap.forEach(series => {

                const firstProject = projects.find(project => series.projectIds.includes(project.id));

                entries.push(this.makeEntry({
                    id: series.name,
                    entityType: "Series",
                    route: "projects",
                    projectId: firstProject?.id || "",
                    projectName: firstProject ? String(firstProject.name || firstProject.title || "") : "",
                    series: series.name,
                    title: series.name,
                    previewText: `${series.projectIds.length} project${series.projectIds.length === 1 ? "" : "s"}`,
                    searchable: {
                        title: series.name,
                        metadata: ["series"],
                        content: []
                    },
                    metadata: {
                        status: "",
                        category: "Series",
                        tags: [],
                        priority: ""
                    },
                    createdAt: firstProject?.createdAt,
                    updatedAt: firstProject?.updatedAt || firstProject?.lastModified,
                    archived: false,
                    nav: {
                        series: series.name,
                        firstProjectId: firstProject?.id || ""
                    }
                }));

            });

            return entries;

        }


        makeEntry(payload) {

            const title = String(payload.title || "Untitled").trim() || "Untitled";

            const titleText = this.joinSearchText(payload.searchable?.title);
            const metadataText = this.joinSearchText(payload.searchable?.metadata);
            const contentText = this.joinSearchText(payload.searchable?.content);

            return {
                key: `${payload.entityType}:${payload.projectId || "global"}:${payload.id}`,
                id: payload.id,
                entityType: payload.entityType,
                route: payload.route,
                projectId: payload.projectId || "",
                projectName: payload.projectName || "",
                series: payload.series || "",
                title,
                previewText: String(payload.previewText || ""),
                metadata: {
                    status: String(payload.metadata?.status || "").trim(),
                    category: String(payload.metadata?.category || "").trim(),
                    tags: this.stringList(payload.metadata?.tags),
                    priority: String(payload.metadata?.priority || "").trim()
                },
                archived: Boolean(payload.archived),
                createdAt: payload.createdAt || "",
                updatedAt: payload.updatedAt || "",
                nav: payload.nav || {},
                searchableText: {
                    titleRaw: titleText.raw,
                    titleNorm: titleText.norm,
                    metadataRaw: metadataText.raw,
                    metadataNorm: metadataText.norm,
                    contentRaw: contentText.raw,
                    contentNorm: contentText.norm
                }
            };

        }


        joinSearchText(value) {

            if (Array.isArray(value)) {
                const raw = value
                    .map(item => String(item ?? "").trim())
                    .filter(Boolean)
                    .join(" ");

                return {
                    raw,
                    norm: this.normalizeText(raw)
                };
            }

            const raw = String(value ?? "").trim();

            return {
                raw,
                norm: this.normalizeText(raw)
            };

        }


        scoreEntry(entry, query) {

            const titleScore = this.scoreField(entry.searchableText.titleNorm, query);
            const metadataScore = this.scoreField(entry.searchableText.metadataNorm, query);
            const contentScore = this.scoreField(entry.searchableText.contentNorm, query);

            let score = 0;

            score += this.mapFieldScore(titleScore, "title");
            score += this.mapFieldScore(metadataScore, "metadata");
            score += this.mapFieldScore(contentScore, "content");

            if (score <= 0) {
                return {
                    entry,
                    score: 0,
                    matchedField: "",
                    matchSource: ""
                };
            }

            const matchedField = titleScore.rank > 0
                ? "Title"
                : metadataScore.rank > 0
                    ? "Metadata"
                    : "Content";

            const tokenMatches = query.tokens.reduce((acc, token) => {
                if (!token) {
                    return acc;
                }

                let matched = false;

                if (entry.searchableText.titleNorm.includes(token)) {
                    matched = true;
                } else if (entry.searchableText.metadataNorm.includes(token)) {
                    matched = true;
                } else if (entry.searchableText.contentNorm.includes(token)) {
                    matched = true;
                }

                return acc + (matched ? 1 : 0);

            }, 0);

            score += tokenMatches * this.priorityWeights.tokenBonus;

            const matchSource = matchedField === "Title"
                ? entry.searchableText.titleRaw
                : matchedField === "Metadata"
                    ? entry.searchableText.metadataRaw
                    : entry.searchableText.contentRaw || entry.previewText || entry.title;

            return {
                entry,
                score,
                matchedField,
                matchSource
            };

        }


        scoreField(normalizedField, query) {

            if (!normalizedField || !query.canonical) {
                return {
                    rank: 0
                };
            }

            if (normalizedField === query.canonical) {
                return {
                    rank: 3
                };
            }

            if (normalizedField.startsWith(query.canonical)) {
                return {
                    rank: 2
                };
            }

            if (normalizedField.includes(query.canonical)) {
                return {
                    rank: 1
                };
            }

            return {
                rank: 0
            };

        }


        mapFieldScore(fieldScore, kind) {

            const rank = Number(fieldScore?.rank || 0);

            if (rank <= 0) {
                return 0;
            }

            if (kind === "title") {
                if (rank === 3) {
                    return this.priorityWeights.titleExact;
                }
                if (rank === 2) {
                    return this.priorityWeights.titleStarts;
                }
                return this.priorityWeights.titleContains;
            }

            if (kind === "metadata") {
                if (rank === 3) {
                    return this.priorityWeights.metadataExact;
                }
                if (rank === 2) {
                    return this.priorityWeights.metadataStarts;
                }
                return this.priorityWeights.metadataContains;
            }

            if (rank === 3) {
                return this.priorityWeights.contentExact;
            }
            if (rank === 2) {
                return this.priorityWeights.contentStarts;
            }
            return this.priorityWeights.contentContains;

        }


        toResult(scored, query) {

            const entry = scored.entry;

            const excerpt = this.buildExcerpt(
                scored.matchSource || entry.previewText || entry.title,
                query
            );

            return {
                key: entry.key,
                id: entry.id,
                entityType: entry.entityType,
                title: entry.title,
                route: entry.route,
                projectId: entry.projectId,
                projectName: entry.projectName,
                series: entry.series,
                archived: entry.archived,
                metadata: {
                    status: entry.metadata.status,
                    category: entry.metadata.category,
                    tags: [...entry.metadata.tags],
                    priority: entry.metadata.priority,
                    createdAt: entry.createdAt || "",
                    updatedAt: entry.updatedAt || ""
                },
                matchedField: scored.matchedField,
                preview: excerpt,
                score: scored.score,
                nav: { ...entry.nav }
            };

        }


        buildExcerpt(text, query) {

            const source = String(text || "").replace(/\s+/g, " ").trim();

            if (!source) {
                return "";
            }

            if (!query || !query.tokens?.length) {
                return source.slice(0, 220);
            }

            const lowerSource = source.toLowerCase();

            let matchIndex = -1;

            query.tokens.forEach(token => {
                if (matchIndex !== -1 || !token) {
                    return;
                }

                const index = lowerSource.indexOf(token.toLowerCase());

                if (index !== -1) {
                    matchIndex = index;
                }
            });

            if (matchIndex === -1) {
                return source.slice(0, 220);
            }

            const start = Math.max(0, matchIndex - 80);
            const end = Math.min(source.length, matchIndex + 140);

            let excerpt = source.slice(start, end);

            if (start > 0) {
                excerpt = `...${excerpt}`;
            }

            if (end < source.length) {
                excerpt = `${excerpt}...`;
            }

            return excerpt;

        }


        highlightMatches(text, query) {

            const source = String(text || "");
            const escaped = this.escapeHTML(source);

            if (!query || !query.tokens?.length) {
                return escaped;
            }

            const tokens = Array.from(new Set(
                query.tokens
                    .map(token => String(token || "").trim())
                    .filter(Boolean)
            ))
                .sort((left, right) => right.length - left.length)
                .map(token => this.escapeRegex(token));

            if (!tokens.length) {
                return escaped;
            }

            const pattern = new RegExp(`(${tokens.join("|")})`, "gi");

            return escaped.replace(pattern, "<mark>$1</mark>");

        }


        getScopedEntries(entries, scope, currentProjectId) {

            if (!Array.isArray(entries)) {
                return [];
            }

            if (scope === "all-projects") {
                return entries;
            }

            if (!currentProjectId) {
                return entries.filter(entry => entry.entityType === "Idea");
            }

            const projects = this.getProjects();
            const current = projects.find(project => project.id === currentProjectId) || null;

            if (!current) {
                return entries;
            }

            if (scope === "current-project") {
                return entries.filter(entry => {
                    if (entry.projectId) {
                        return entry.projectId === currentProjectId;
                    }

                    if (entry.entityType === "Idea") {
                        return entry.projectId === currentProjectId || entry.projectId === "";
                    }

                    return false;
                });
            }

            const currentSeries = String(current.series || "").trim();

            if (!currentSeries) {
                return entries.filter(entry => entry.projectId === currentProjectId);
            }

            const seriesProjectIds = new Set(
                projects
                    .filter(project => String(project?.series || "").trim() === currentSeries)
                    .map(project => project.id)
            );

            return entries.filter(entry => {
                if (entry.projectId && seriesProjectIds.has(entry.projectId)) {
                    return true;
                }

                if (entry.entityType === "Series" && String(entry.series || "") === currentSeries) {
                    return true;
                }

                return false;
            });

        }


        matchesMetadataFilters(entry, filters, includeArchived) {

            if (!entry || typeof entry !== "object") {
                return false;
            }

            if (!includeArchived && entry.archived) {
                return false;
            }

            if (filters.type !== "All" && entry.entityType !== filters.type) {
                return false;
            }

            if (filters.projectId !== "All" && entry.projectId !== filters.projectId) {
                return false;
            }

            if (filters.series !== "All" && String(entry.series || "") !== filters.series) {
                return false;
            }

            if (filters.status !== "All" && String(entry.metadata?.status || "") !== filters.status) {
                return false;
            }

            if (filters.category !== "All" && String(entry.metadata?.category || "") !== filters.category) {
                return false;
            }

            if (filters.tag !== "All") {
                const tags = this.stringList(entry.metadata?.tags);

                if (!tags.includes(filters.tag)) {
                    return false;
                }
            }

            return true;

        }


        buildFacets(entries, includeArchived) {

            const visible = Array.isArray(entries)
                ? entries.filter(entry => includeArchived || !entry.archived)
                : [];

            const addSorted = set => Array.from(set).filter(Boolean).sort((left, right) => left.localeCompare(right, undefined, { sensitivity: "base" }));

            const types = new Set();
            const projects = new Map();
            const series = new Set();
            const statuses = new Set();
            const categories = new Set();
            const tags = new Set();

            visible.forEach(entry => {
                types.add(String(entry.entityType || "").trim());

                if (entry.projectId && entry.projectName) {
                    projects.set(entry.projectId, entry.projectName);
                }

                if (entry.series) {
                    series.add(String(entry.series));
                }

                if (entry.metadata?.status) {
                    statuses.add(String(entry.metadata.status));
                }

                if (entry.metadata?.category) {
                    categories.add(String(entry.metadata.category));
                }

                this.stringList(entry.metadata?.tags).forEach(tag => {
                    tags.add(tag);
                });
            });

            return {
                types: addSorted(types),
                projects: Array.from(projects.entries())
                    .map(([id, name]) => ({ id, name }))
                    .sort((left, right) => left.name.localeCompare(right.name, undefined, { sensitivity: "base" })),
                series: addSorted(series),
                statuses: addSorted(statuses),
                categories: addSorted(categories),
                tags: addSorted(tags)
            };

        }


        sortResults(results, sort) {

            const list = Array.isArray(results)
                ? [...results]
                : [];

            if (sort === "updated-desc") {
                return list.sort((left, right) => this.safeTime(right.metadata.updatedAt) - this.safeTime(left.metadata.updatedAt));
            }

            if (sort === "created-desc") {
                return list.sort((left, right) => this.safeTime(right.metadata.createdAt) - this.safeTime(left.metadata.createdAt));
            }

            if (sort === "alpha") {
                return list.sort((left, right) => left.title.localeCompare(right.title, undefined, { sensitivity: "base" }));
            }

            return list.sort((left, right) => {

                const scoreDiff = Number(right.score || 0) - Number(left.score || 0);

                if (scoreDiff !== 0) {
                    return scoreDiff;
                }

                const updateDiff = this.safeTime(right.metadata.updatedAt) - this.safeTime(left.metadata.updatedAt);

                if (updateDiff !== 0) {
                    return updateDiff;
                }

                return left.title.localeCompare(right.title, undefined, { sensitivity: "base" });

            });

        }


        safeTime(value) {
            const parsed = Date.parse(value || "");
            return Number.isNaN(parsed) ? 0 : parsed;
        }


        openResult(result) {

            if (!result || typeof result !== "object") {
                return {
                    ok: false,
                    message: "Invalid result target."
                };
            }

            const resolved = this.resolveCurrentEntry(result.key);

            if (!resolved) {
                return {
                    ok: false,
                    message: "This result no longer exists."
                };
            }

            const entry = resolved;

            if (entry.projectId && !this.ensureCurrentProject(entry.projectId)) {
                return {
                    ok: false,
                    message: "Target project could not be opened."
                };
            }

            if (entry.route === "project-workspace") {
                const projectsModule = this.core.registry.get("projects");

                if (!projectsModule || typeof projectsModule.openProject !== "function") {
                    return {
                        ok: false,
                        message: "Project navigation is unavailable."
                    };
                }

                projectsModule.openProject(entry.projectId);
                return { ok: true };
            }

            if (entry.route === "ideas") {
                const ideasModule = this.core.registry.get("ideas");
                if (ideasModule) {
                    ideasModule.selectedIdeaId = entry.nav.ideaId || entry.id;
                }
                this.core.navigation.navigate("ideas");
                return { ok: true };
            }

            if (entry.route === "manuscript") {
                const manuscriptModule = this.core.registry.get("manuscript");
                if (manuscriptModule && entry.nav.chapterId) {
                    manuscriptModule.activeChapterId = entry.nav.chapterId;
                }
                this.core.navigation.navigate("manuscript");
                return { ok: true };
            }

            if (entry.route === "characters") {
                const charactersModule = this.core.registry.get("characters");
                if (charactersModule && entry.nav.characterId) {
                    charactersModule.selectedCharacterId = entry.nav.characterId;
                }
                this.core.navigation.navigate("characters");
                return { ok: true };
            }

            if (entry.route === "world") {
                const worldModule = this.core.registry.get("world");
                if (worldModule && entry.nav.worldEntryId) {
                    worldModule.selectedEntryId = entry.nav.worldEntryId;
                }
                this.core.navigation.navigate("world");
                return { ok: true };
            }

            if (entry.route === "plot") {
                const plotModule = this.core.registry.get("plot");
                if (plotModule && entry.nav.plotType && entry.nav.plotId) {
                    plotModule.selectedEntity = {
                        type: entry.nav.plotType,
                        id: entry.nav.plotId
                    };
                }
                this.core.navigation.navigate("plot");
                return { ok: true };
            }

            if (entry.route === "timeline") {
                const timelineModule = this.core.registry.get("timeline");
                if (timelineModule && entry.nav.timelineType && entry.nav.timelineId) {
                    timelineModule.selectedEntity = {
                        type: entry.nav.timelineType,
                        id: entry.nav.timelineId
                    };
                }
                this.core.navigation.navigate("timeline");
                return { ok: true };
            }

            if (entry.route === "notes") {
                const notesModule = this.core.registry.get("notes");
                if (notesModule && entry.nav.notesKind && entry.nav.notesId) {
                    notesModule.selectedEntity = {
                        kind: entry.nav.notesKind,
                        id: entry.nav.notesId
                    };
                }
                this.core.navigation.navigate("notes");
                return { ok: true };
            }

            if (entry.route === "projects") {
                if (entry.nav.firstProjectId) {
                    const projectsModule = this.core.registry.get("projects");

                    if (projectsModule && typeof projectsModule.openProject === "function") {
                        projectsModule.openProject(entry.nav.firstProjectId);
                        return { ok: true };
                    }
                }

                this.core.navigation.navigate("projects");
                return { ok: true };
            }

            this.core.navigation.navigate(entry.route);
            return { ok: true };

        }


        resolveCurrentEntry(key) {

            const entries = this.rebuildIndex();

            return entries.find(entry => entry.key === key) || null;

        }


        ensureCurrentProject(projectId) {

            if (!projectId) {
                return true;
            }

            const projects = this.getProjects();
            const project = projects.find(item => item.id === projectId) || null;

            if (!project) {
                return false;
            }

            if (String(project.status || "").toLowerCase() === "archived") {
                return false;
            }

            this.core.state.set("currentProject", project);
            this.core.storage.saveActiveProjectId(projectId);

            return true;

        }


        getCurrentProjectId() {

            const current = this.core.state.get("currentProject");

            if (current?.id) {
                return current.id;
            }

            return this.core.storage.loadActiveProjectId() || "";

        }


        getProjects() {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects) ? projects : [];
        }


        getIdeas() {
            const ideas = this.core.state.get("ideas");
            return Array.isArray(ideas) ? ideas : [];
        }


        getProjectChapters(project) {
            return Array.isArray(project?.manuscript?.chapters)
                ? project.manuscript.chapters.filter(chapter => chapter && chapter.id)
                : [];
        }


        getProjectCharacters(project) {
            return Array.isArray(project?.story?.characters)
                ? project.story.characters.filter(item => item && item.id)
                : [];
        }


        getProjectWorldEntries(project) {
            return Array.isArray(project?.story?.worldEntries)
                ? project.story.worldEntries.filter(item => item && item.id)
                : [];
        }


        getProjectPlot(project) {

            const plot = project?.story?.plot;

            if (!plot || typeof plot !== "object") {
                return {
                    arcs: [],
                    acts: [],
                    beats: [],
                    threads: [],
                    scenes: []
                };
            }

            return {
                arcs: Array.isArray(plot.arcs) ? plot.arcs : [],
                acts: Array.isArray(plot.acts) ? plot.acts : [],
                beats: Array.isArray(plot.beats) ? plot.beats : [],
                threads: Array.isArray(plot.threads) ? plot.threads : [],
                scenes: Array.isArray(plot.scenes) ? plot.scenes : []
            };

        }


        getProjectTimeline(project) {

            const timeline = project?.story?.timeline;

            if (!timeline || typeof timeline !== "object" || Array.isArray(timeline)) {
                return {
                    events: []
                };
            }

            return {
                events: Array.isArray(timeline.events) ? timeline.events : []
            };

        }


        getProjectNotesStudio(project) {

            const notes = project?.story?.notesStudio;

            if (!notes || typeof notes !== "object") {
                return {
                    records: [],
                    sources: []
                };
            }

            return {
                records: Array.isArray(notes.records) ? notes.records : [],
                sources: Array.isArray(notes.sources) ? notes.sources : []
            };

        }


        stringList(value) {

            if (!Array.isArray(value)) {
                return [];
            }

            return value
                .map(item => String(item || "").trim())
                .filter(Boolean);

        }


        saveRecentQuery(query) {

            const normalized = this.normalizeQuery(query);

            if (!normalized.canonical || normalized.canonical.length < 2) {
                return;
            }

            const next = [
                normalized.collapsed,
                ...this.getRecentQueries().filter(item => this.normalizeText(item) !== normalized.canonical)
            ].slice(0, this.maxRecent);

            this.safeSetStorage(this.recentSearchStorageKey, JSON.stringify(next));

        }


        getRecentQueries() {

            const raw = this.safeGetStorage(this.recentSearchStorageKey);

            if (!raw) {
                return [];
            }

            try {
                const parsed = JSON.parse(raw);
                return Array.isArray(parsed)
                    ? parsed
                        .map(item => String(item || "").trim())
                        .filter(Boolean)
                        .slice(0, this.maxRecent)
                    : [];
            } catch (error) {
                return [];
            }

        }


        clearRecentQueries() {
            this.safeSetStorage(this.recentSearchStorageKey, JSON.stringify([]));
        }


        safeGetStorage(key) {

            try {
                return window.localStorage.getItem(key);
            } catch (error) {
                return null;
            }

        }


        safeSetStorage(key, value) {

            try {
                window.localStorage.setItem(key, String(value || ""));
            } catch (error) {
                return;
            }

        }


        escapeRegex(value) {
            return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        }


        escapeHTML(value) {
            return String(value || "")
                .replaceAll("&", "&amp;")
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;")
                .replaceAll('"', "&quot;")
                .replaceAll("'", "&#39;");
        }

    }


    window.AuthorOSSearch =
        AuthorOSSearch;

})();