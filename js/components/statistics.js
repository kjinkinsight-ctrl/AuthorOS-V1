/*
=========================================================
AUTHOROS
STATISTICS SERVICE
Milestone 12
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSStatisticsService {

        constructor(core) {
            this.core = core;

            this.cache = {
                signature: "",
                bundles: new Map()
            };
        }


        getScopeBundle(options = {}) {

            const scope = this.normalizeScope(options.scope);
            const projectId = String(options.projectId || "").trim();
            const series = String(options.series || "").trim();

            const signature = this.getSignature();
            const key = `${scope}|${projectId}|${series}|${signature}`;

            if (this.cache.bundles.has(key)) {
                return this.cache.bundles.get(key);
            }

            if (this.cache.signature !== signature) {
                this.cache.signature = signature;
                this.cache.bundles.clear();
            }

            const projects = this.getScopeProjects(scope, projectId, series);

            const bundle = {
                scope,
                projectId,
                series,
                projects,
                projectCount: projects.length,
                summary: this.calculateSummary(projects),
                manuscript: this.calculateManuscriptMetrics(projects),
                chapters: this.calculateChapterAnalytics(projects),
                goals: this.calculateGoalMetrics(projects),
                activity: this.calculateActivityMetrics(projects),
                characters: this.calculateCharacterMetrics(projects),
                world: this.calculateWorldMetrics(projects),
                plot: this.calculatePlotMetrics(projects),
                timeline: this.calculateTimelineMetrics(projects),
                notes: this.calculateNotesMetrics(projects),
                seriesRollup: this.calculateSeriesRollup(projects)
            };

            this.cache.bundles.set(key, bundle);
            return bundle;

        }


        normalizeScope(scope) {
            const value = String(scope || "current-project").trim();
            const allowed = ["current-project", "current-series", "all-projects"];
            return allowed.includes(value) ? value : "current-project";
        }


        getSignature() {

            const projects = this.getProjects();

            return projects
                .map(project => `${project.id || ""}:${project.updatedAt || project.lastModified || ""}:${project.lastOpened || ""}`)
                .join("|");

        }


        getProjects() {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects) ? projects : [];
        }


        getCurrentProject() {

            const fromState = this.core.state.get("currentProject");

            if (fromState && fromState.id) {
                return fromState;
            }

            const activeId = this.core.storage.loadActiveProjectId();

            if (!activeId) {
                return null;
            }

            return this.getProjects().find(project => project.id === activeId) || null;

        }


        getScopeProjects(scope, projectId, series) {

            const projects = this.getProjects();

            if (scope === "all-projects") {
                return projects.filter(project => String(project?.status || "") !== "Archived");
            }

            if (scope === "current-series") {

                const seedProject = projectId
                    ? projects.find(project => project.id === projectId) || null
                    : this.getCurrentProject();

                const seriesName = series || String(seedProject?.series || "").trim();

                if (!seriesName) {
                    return seedProject ? [seedProject] : [];
                }

                return projects.filter(project => {
                    if (String(project?.status || "") === "Archived") {
                        return false;
                    }

                    return String(project?.series || "").trim() === seriesName;
                });
            }

            const targetProject = projectId
                ? projects.find(project => project.id === projectId) || null
                : this.getCurrentProject();

            if (!targetProject || String(targetProject?.status || "") === "Archived") {
                return [];
            }

            return [targetProject];

        }


        calculateSummary(projects) {

            const projectList = Array.isArray(projects) ? projects : [];

            const words = projectList.reduce((sum, project) => sum + this.getProjectWordCount(project), 0);
            const chapters = projectList.reduce((sum, project) => sum + this.getProjectChapters(project).length, 0);
            const scenes = projectList.reduce((sum, project) => sum + this.getPlotScenes(project).length, 0);
            const characters = projectList.reduce((sum, project) => sum + this.getCharacters(project).length, 0);
            const worldEntries = projectList.reduce((sum, project) => sum + this.getWorldEntries(project).length, 0);
            const plotItems = projectList.reduce((sum, project) => {
                const plot = this.getPlot(project);
                return sum + plot.arcs.length + plot.acts.length + plot.beats.length + plot.threads.length + plot.scenes.length;
            }, 0);
            const timelineEvents = projectList.reduce((sum, project) => sum + this.getTimeline(project).events.length, 0);

            const notesStats = projectList.reduce((acc, project) => {
                const notes = this.getNotesStudio(project);
                acc.notes += notes.records.filter(record => String(record?.type || "") === "Note").length;
                acc.research += notes.records.filter(record => String(record?.type || "") === "Research").length;
                acc.sources += notes.sources.length;
                return acc;
            }, { notes: 0, research: 0, sources: 0 });

            const updatedAt = projectList
                .map(project => this.safeTime(project?.updatedAt || project?.lastModified))
                .filter(value => value > 0)
                .sort((a, b) => b - a)[0] || 0;

            return {
                words,
                chapters,
                scenes,
                characters,
                worldEntries,
                plotItems,
                timelineEvents,
                notes: notesStats.notes,
                research: notesStats.research,
                sources: notesStats.sources,
                projectCount: projectList.length,
                updatedAt: updatedAt ? new Date(updatedAt).toISOString() : ""
            };

        }


        calculateManuscriptMetrics(projects) {

            const allChapters = projects.flatMap(project => this.getProjectChapters(project).map(chapter => ({
                ...chapter,
                _projectId: project.id,
                _projectName: this.getProjectName(project)
            })));

            const words = allChapters.reduce((sum, chapter) => sum + this.countWords(chapter.content), 0);
            const chapterCount = allChapters.length;
            const averageChapterWords = chapterCount > 0 ? Math.round(words / chapterCount) : 0;

            const shortest = allChapters
                .map(chapter => ({ chapter, words: this.countWords(chapter.content) }))
                .sort((left, right) => left.words - right.words)[0] || null;

            const longest = allChapters
                .map(chapter => ({ chapter, words: this.countWords(chapter.content) }))
                .sort((left, right) => right.words - left.words)[0] || null;

            const sceneList = projects.flatMap(project => this.getPlotScenes(project).map(scene => ({
                ...scene,
                _projectId: project.id,
                _projectName: this.getProjectName(project)
            })));

            const sceneByStatus = this.countBy(sceneList, scene => String(scene?.status || "Unknown").trim() || "Unknown");
            const plannedScenes = sceneList.filter(scene => String(scene?.status || "") === "Planned").length;
            const completeScenes = sceneList.filter(scene => String(scene?.status || "") === "Complete").length;

            return {
                totalWords: words,
                chapterCount,
                sceneCount: sceneList.length,
                averageChapterWords,
                shortestChapter: shortest
                    ? {
                        projectId: shortest.chapter._projectId,
                        projectName: shortest.chapter._projectName,
                        chapterId: shortest.chapter.id,
                        title: String(shortest.chapter.title || "Untitled Chapter"),
                        words: shortest.words
                    }
                    : null,
                longestChapter: longest
                    ? {
                        projectId: longest.chapter._projectId,
                        projectName: longest.chapter._projectName,
                        chapterId: longest.chapter.id,
                        title: String(longest.chapter.title || "Untitled Chapter"),
                        words: longest.words
                    }
                    : null,
                chapterStatusAvailable: false,
                chapterStatusMessage: "Chapter status field is not present in the canonical chapter model.",
                sceneWordMetricsAvailable: false,
                sceneWordMetricsMessage: "Scene-level word content is not stored in canonical data.",
                sceneByStatus,
                plannedScenes,
                completeScenes
            };

        }


        calculateChapterAnalytics(projects) {

            const rows = [];

            projects.forEach(project => {

                const chapters = this.getProjectChapters(project);
                const scenes = this.getPlotScenes(project);

                chapters.forEach((chapter, index) => {

                    const linkedScenes = scenes.filter(scene => String(scene?.chapterId || "") === String(chapter.id));
                    const words = this.countWords(chapter.content);

                    const completeScenes = linkedScenes.filter(scene => String(scene?.status || "") === "Complete").length;

                    let status = "Unspecified";

                    if (linkedScenes.length > 0) {
                        status = completeScenes === linkedScenes.length ? "Complete" : "Draft";
                    }

                    rows.push({
                        projectId: project.id,
                        projectName: this.getProjectName(project),
                        chapterId: chapter.id,
                        title: String(chapter.title || `Chapter ${index + 1}`),
                        order: Number.isFinite(Number(chapter.order)) ? Number(chapter.order) : index + 1,
                        words,
                        sceneCount: linkedScenes.length,
                        completeScenes,
                        status,
                        updatedAt: chapter.updatedAt || chapter.createdAt || ""
                    });

                });

            });

            rows.sort((left, right) => {
                const projectDiff = left.projectName.localeCompare(right.projectName, undefined, { sensitivity: "base" });
                if (projectDiff !== 0) {
                    return projectDiff;
                }
                return left.order - right.order;
            });

            const wordValues = rows.map(row => row.words);
            const min = wordValues.length ? Math.min(...wordValues) : 0;
            const max = wordValues.length ? Math.max(...wordValues) : 0;
            const avg = wordValues.length ? Math.round(wordValues.reduce((sum, value) => sum + value, 0) / wordValues.length) : 0;

            return {
                rows,
                averageWords: avg,
                minWords: min,
                maxWords: max
            };

        }


        calculateGoalMetrics(projects) {

            const targets = projects.map(project => ({
                projectId: project.id,
                projectName: this.getProjectName(project),
                target: this.getGoalTargetWords(project),
                current: this.getProjectWordCount(project)
            }));

            const withGoals = targets.filter(item => item.target > 0);

            const totalTarget = withGoals.reduce((sum, item) => sum + item.target, 0);
            const totalCurrent = withGoals.reduce((sum, item) => sum + item.current, 0);

            const percent = totalTarget > 0
                ? Math.max(0, Math.min(100, Math.round((totalCurrent / totalTarget) * 100)))
                : 0;

            return {
                available: withGoals.length > 0,
                projectsWithGoals: withGoals,
                totalTarget,
                totalCurrent,
                remaining: Math.max(0, totalTarget - totalCurrent),
                percent
            };

        }


        calculateActivityMetrics(projects) {

            const chapterDates = [];

            projects.forEach(project => {
                this.getProjectChapters(project).forEach(chapter => {
                    const updatedAt = this.safeDate(chapter.updatedAt || chapter.createdAt);
                    if (updatedAt) {
                        chapterDates.push(updatedAt);
                    }
                });
            });

            const uniqueDays = new Set(chapterDates.map(date => date.toISOString().slice(0, 10)));

            const now = new Date();
            const sevenDaysAgo = new Date(now);
            sevenDaysAgo.setDate(now.getDate() - 7);

            const thirtyDaysAgo = new Date(now);
            thirtyDaysAgo.setDate(now.getDate() - 30);

            const recent7 = chapterDates.filter(date => date >= sevenDaysAgo).length;
            const recent30 = chapterDates.filter(date => date >= thirtyDaysAgo).length;

            const latest = chapterDates.sort((a, b) => b.getTime() - a.getTime())[0] || null;

            return {
                activeWritingDays: uniqueDays.size,
                chapterUpdatesLast7Days: recent7,
                chapterUpdatesLast30Days: recent30,
                latestChapterUpdate: latest ? latest.toISOString() : "",
                historicalWordGrowthAvailable: false,
                historicalWordGrowthMessage: "Historical word-growth snapshots are not present in canonical storage."
            };

        }


        calculateCharacterMetrics(projects) {

            const list = projects.flatMap(project => this.getCharacters(project));

            return {
                total: list.length,
                active: list.filter(character => String(character?.status || "") !== "Archived").length,
                archived: list.filter(character => String(character?.status || "") === "Archived").length,
                byRole: this.countBy(list, character => String(character?.role || "Other").trim() || "Other"),
                byStatus: this.countBy(list, character => String(character?.status || "Draft").trim() || "Draft")
            };

        }


        calculateWorldMetrics(projects) {

            const list = projects.flatMap(project => this.getWorldEntries(project));

            return {
                total: list.length,
                active: list.filter(entry => String(entry?.status || "") !== "Archived").length,
                archived: list.filter(entry => String(entry?.status || "") === "Archived").length,
                byType: this.countBy(list, entry => String(entry?.type || "Lore").trim() || "Lore"),
                byStatus: this.countBy(list, entry => String(entry?.status || "Draft").trim() || "Draft")
            };

        }


        calculatePlotMetrics(projects) {

            const arcs = projects.flatMap(project => this.getPlot(project).arcs);
            const acts = projects.flatMap(project => this.getPlot(project).acts);
            const beats = projects.flatMap(project => this.getPlot(project).beats);
            const threads = projects.flatMap(project => this.getPlot(project).threads);
            const scenes = projects.flatMap(project => this.getPlot(project).scenes);

            return {
                arcs: arcs.length,
                acts: acts.length,
                beats: beats.length,
                threads: threads.length,
                scenes: scenes.length,
                plannedScenes: scenes.filter(scene => String(scene?.status || "") === "Planned").length,
                completeScenes: scenes.filter(scene => String(scene?.status || "") === "Complete").length,
                sceneByStatus: this.countBy(scenes, scene => String(scene?.status || "Planned").trim() || "Planned")
            };

        }


        calculateTimelineMetrics(projects) {

            const timelines = projects.map(project => ({
                project,
                timeline: this.getTimeline(project)
            }));

            const events = timelines.flatMap(item => item.timeline.events);
            const eras = timelines.flatMap(item => item.timeline.eras);
            const sequences = timelines.flatMap(item => item.timeline.sequences);

            let warnings = 0;
            const timelineModule = this.core.registry.get("timeline");

            if (timelineModule && typeof timelineModule.getTimelineSummaryCounts === "function") {
                warnings = projects.reduce((sum, project) => {
                    const metrics = timelineModule.getTimelineSummaryCounts(project.id);
                    return sum + Number(metrics?.warnings || 0);
                }, 0);
            }

            return {
                events: events.length,
                eras: eras.length,
                sequences: sequences.length,
                warnings,
                byType: this.countBy(events, event => String(event?.type || "Custom").trim() || "Custom"),
                byStatus: this.countBy(events, event => String(event?.status || "Planned").trim() || "Planned")
            };

        }


        calculateNotesMetrics(projects) {

            const notesStudio = projects.map(project => this.getNotesStudio(project));

            const records = notesStudio.flatMap(item => item.records);
            const sources = notesStudio.flatMap(item => item.sources);

            const notes = records.filter(record => String(record?.type || "") === "Note");
            const research = records.filter(record => String(record?.type || "") === "Research");

            return {
                notes: notes.length,
                research: research.length,
                sources: sources.length,
                byCategory: this.countBy(records, record => String(record?.category || "General").trim() || "General"),
                byStatus: this.countBy(records, record => String(record?.status || "Draft").trim() || "Draft")
            };

        }


        calculateSeriesRollup(projects) {

            const grouped = {};

            projects.forEach(project => {

                const series = String(project?.series || "").trim() || "Standalone";

                if (!grouped[series]) {
                    grouped[series] = {
                        projectCount: 0,
                        words: 0,
                        chapters: 0,
                        scenes: 0,
                        statuses: {},
                        books: []
                    };
                }

                grouped[series].projectCount += 1;
                grouped[series].words += this.getProjectWordCount(project);
                grouped[series].chapters += this.getProjectChapters(project).length;
                grouped[series].scenes += this.getPlotScenes(project).length;

                const status = String(project?.status || "Draft").trim() || "Draft";
                grouped[series].statuses[status] = (grouped[series].statuses[status] || 0) + 1;

                grouped[series].books.push({
                    projectId: project.id,
                    name: this.getProjectName(project),
                    words: this.getProjectWordCount(project),
                    status
                });

            });

            return grouped;

        }


        countBy(list, resolver) {

            const counts = {};

            (Array.isArray(list) ? list : []).forEach(item => {
                const key = String(resolver(item) || "Unknown").trim() || "Unknown";
                counts[key] = (counts[key] || 0) + 1;
            });

            return counts;

        }


        getProjectName(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        }


        getProjectWordCount(project) {
            return this.getProjectChapters(project)
                .reduce((sum, chapter) => sum + this.countWords(chapter.content), 0);
        }


        getGoalTargetWords(project) {

            const fromManuscript = Number(project?.manuscript?.goalTargetWords);

            if (Number.isFinite(fromManuscript) && fromManuscript >= 0) {
                return Math.trunc(fromManuscript);
            }

            const fromProject = Number(project?.targetWords ?? project?.targetWordCount);

            return Number.isFinite(fromProject) && fromProject >= 0
                ? Math.trunc(fromProject)
                : 0;

        }


        getProjectChapters(project) {
            return Array.isArray(project?.manuscript?.chapters)
                ? project.manuscript.chapters.filter(chapter => chapter && chapter.id)
                : [];
        }


        getCharacters(project) {
            return Array.isArray(project?.story?.characters)
                ? project.story.characters.filter(item => item && item.id)
                : [];
        }


        getWorldEntries(project) {
            return Array.isArray(project?.story?.worldEntries)
                ? project.story.worldEntries.filter(item => item && item.id)
                : [];
        }


        getPlot(project) {

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


        getPlotScenes(project) {
            return this.getPlot(project).scenes;
        }


        getTimeline(project) {

            const timeline = project?.story?.timeline;

            if (!timeline || typeof timeline !== "object" || Array.isArray(timeline)) {
                return {
                    eras: [],
                    sequences: [],
                    events: []
                };
            }

            return {
                eras: Array.isArray(timeline.eras) ? timeline.eras : [],
                sequences: Array.isArray(timeline.sequences) ? timeline.sequences : [],
                events: Array.isArray(timeline.events) ? timeline.events : []
            };

        }


        getNotesStudio(project) {

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


        countWords(content) {

            const text = String(content || "").trim();

            if (!text) {
                return 0;
            }

            return text.split(/\s+/).filter(Boolean).length;

        }


        safeTime(value) {
            const parsed = Date.parse(value || "");
            return Number.isNaN(parsed) ? 0 : parsed;
        }


        safeDate(value) {
            const parsed = new Date(value || "");
            return Number.isNaN(parsed.getTime()) ? null : parsed;
        }

    }


    window.AuthorOSStatisticsService =
        AuthorOSStatisticsService;

})();
