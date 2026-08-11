/*
=========================================================
AUTHOROS
BACKUP & EXPORT SERVICE
Milestone 13
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSBackupExportService {

        constructor(core) {
            this.core = core;

            this.formatVersion = "1.0.0";
            this.supportedFormatVersions = new Set(["1", "1.0.0"]);
            this.maxImportBytes = 12 * 1024 * 1024;
            this.allowedImportExtensions = [".json"];
            this.maxDocumentImportBytes = 4 * 1024 * 1024;
            this.allowedDocumentImportExtensions = [".txt", ".md", ".markdown", ".html", ".htm", ".doc"];
        }


        async exportFullBackup() {

            const payload = {
                formatVersion: this.formatVersion,
                authorOSVersion: this.getAuthorOSVersion(),
                exportedAt: new Date().toISOString(),
                scope: "full",
                metadata: {},
                data: {
                    projects: this.getProjects().map(project => this.prepareProjectForExport(project)),
                    ideas: this.getIdeas().map(idea => this.prepareIdeaForExport(idea)),
                    settings: this.prepareSettingsForExport(this.getSettings())
                }
            };

            payload.metadata = this.buildBackupMetadata(payload);

            const validation = this.validateBackupPayload(payload, { strictRelationships: true });

            if (!validation.ok) {
                return {
                    ok: false,
                    error: "Full backup validation failed.",
                    validation
                };
            }

            const fileName = `Author-Studio-Full-Backup-${this.getDateStamp()}.json`;

            const downloaded = await this.downloadJson(payload, fileName);

            if (!downloaded.ok) {
                return downloaded;
            }

            this.saveRecentExportInfo({
                type: "full-backup",
                fileName,
                exportedAt: payload.exportedAt,
                projectCount: payload.metadata.counts.projects,
                ideaCount: payload.metadata.counts.ideas,
                bytes: downloaded.bytes || 0
            });

            return {
                ok: true,
                payload,
                fileName,
                bytes: downloaded.bytes || 0,
                validation
            };

        }


        async exportProjectBackup(projectId) {

            const project = this.getProjects().find(item => item.id === projectId) || null;

            if (!project) {
                return {
                    ok: false,
                    error: "Project could not be found for backup."
                };
            }

            const payload = {
                formatVersion: this.formatVersion,
                authorOSVersion: this.getAuthorOSVersion(),
                exportedAt: new Date().toISOString(),
                scope: "project",
                metadata: {},
                data: {
                    projects: [this.prepareProjectForExport(project)],
                    ideas: []
                }
            };

            payload.metadata = this.buildBackupMetadata(payload);

            const validation = this.validateBackupPayload(payload, { strictRelationships: true });

            if (!validation.ok) {
                return {
                    ok: false,
                    error: "Project backup validation failed.",
                    validation
                };
            }

            const label = this.sanitizeFilenamePart(this.getProjectTitle(project));
            const fileName = `Author-Studio-Project-${label}-${this.getDateStamp()}.json`;

            const downloaded = await this.downloadJson(payload, fileName);

            if (!downloaded.ok) {
                return downloaded;
            }

            this.saveRecentExportInfo({
                type: "project-backup",
                fileName,
                exportedAt: payload.exportedAt,
                projectCount: 1,
                ideaCount: 0,
                bytes: downloaded.bytes || 0
            });

            return {
                ok: true,
                payload,
                fileName,
                bytes: downloaded.bytes || 0,
                validation
            };

        }


        async exportStructuredProject(projectId) {

            const project = this.getProjects().find(item => item.id === projectId) || null;

            if (!project) {
                return {
                    ok: false,
                    error: "Project could not be found for export."
                };
            }

            const payload = {
                formatVersion: this.formatVersion,
                authorOSVersion: this.getAuthorOSVersion(),
                exportedAt: new Date().toISOString(),
                scope: "structured-project",
                metadata: {},
                data: {
                    projects: [this.prepareProjectForExport(project)],
                    ideas: []
                }
            };

            payload.metadata = this.buildBackupMetadata(payload);

            const validation = this.validateBackupPayload(payload, { strictRelationships: true });

            if (!validation.ok) {
                return {
                    ok: false,
                    error: "Structured export validation failed.",
                    validation
                };
            }

            const label = this.sanitizeFilenamePart(this.getProjectTitle(project));
            const fileName = `Author-Studio-Project-Structured-${label}-${this.getDateStamp()}.json`;

            const downloaded = await this.downloadJson(payload, fileName);

            if (!downloaded.ok) {
                return downloaded;
            }

            this.saveRecentExportInfo({
                type: "project-structured",
                fileName,
                exportedAt: payload.exportedAt,
                projectCount: 1,
                ideaCount: 0,
                bytes: downloaded.bytes || 0
            });

            return {
                ok: true,
                payload,
                fileName,
                bytes: downloaded.bytes || 0,
                validation
            };

        }


        async exportManuscript(projectId, format, options = {}) {

            const project = this.getProjects().find(item => item.id === projectId) || null;

            if (!project) {
                return {
                    ok: false,
                    error: "Project could not be found for manuscript export."
                };
            }

            const chapters = this.getProjectChapters(project)
                .slice()
                .sort((left, right) => {
                    const leftOrder = Number.isFinite(Number(left.order)) ? Number(left.order) : 0;
                    const rightOrder = Number.isFinite(Number(right.order)) ? Number(right.order) : 0;
                    return leftOrder - rightOrder;
                });

            const normalizedFormat = this.normalizeManuscriptFormat(format);

            const label = this.sanitizeFilenamePart(this.getProjectTitle(project));

            if (normalizedFormat === "pdf") {

                const pdfOptions = this.normalizePdfExportOptions(options);

                const fileName = `Author-Studio-Manuscript-${label}-${this.getDateStamp()}.pdf`;
                const content = this.buildManuscriptHtmlDocument(project, chapters, {
                    titleOverride: fileName,
                    pageSize: pdfOptions.pageSize,
                    margin: pdfOptions.margin,
                    includeChapterTitles: pdfOptions.includeChapterTitles
                });

                const delivered = this.openPrintDialogForPdf(content);

                if (!delivered.ok) {
                    return delivered;
                }

                this.saveRecentExportInfo({
                    type: "manuscript-pdf",
                    fileName,
                    exportedAt: new Date().toISOString(),
                    projectCount: 1,
                    ideaCount: 0,
                    bytes: 0
                });

                return {
                    ok: true,
                    fileName,
                    bytes: 0,
                    chapterCount: chapters.length,
                    delivery: "print-dialog"
                };

            }

            const built = this.buildManuscriptText(project, chapters, normalizedFormat);

            if (!built.ok) {
                return built;
            }

            const fileName = `Author-Studio-Manuscript-${label}-${this.getDateStamp()}.${built.extension}`;

            const downloaded = await this.downloadText(built.content, fileName, built.mimeType);

            if (!downloaded.ok) {
                return downloaded;
            }

            this.saveRecentExportInfo({
                type: `manuscript-${normalizedFormat}`,
                fileName,
                exportedAt: new Date().toISOString(),
                projectCount: 1,
                ideaCount: 0,
                bytes: downloaded.bytes || 0
            });

            return {
                ok: true,
                fileName,
                bytes: downloaded.bytes || 0,
                chapterCount: chapters.length
            };

        }


        buildManuscriptText(project, chapters, format) {

            if (format === "txt") {

                const lines = [];

                lines.push(this.getProjectTitle(project));
                lines.push("");

                chapters.forEach((chapter, index) => {
                    const title = this.getChapterTitle(chapter, index);
                    lines.push(title);
                    lines.push("=".repeat(Math.max(3, title.length)));
                    lines.push("");
                    lines.push(String(chapter.content || ""));
                    lines.push("");
                });

                return {
                    ok: true,
                    content: lines.join("\n"),
                    extension: "txt",
                    mimeType: "text/plain;charset=utf-8"
                };

            }

            if (format === "md") {

                const lines = [];

                lines.push(`# ${this.escapeText(this.getProjectTitle(project))}`);
                lines.push("");

                chapters.forEach((chapter, index) => {
                    lines.push(`## ${this.escapeText(this.getChapterTitle(chapter, index))}`);
                    lines.push("");
                    lines.push(String(chapter.content || ""));
                    lines.push("");
                });

                return {
                    ok: true,
                    content: lines.join("\n"),
                    extension: "md",
                    mimeType: "text/markdown;charset=utf-8"
                };

            }

            if (format === "html") {

                const content = this.buildManuscriptHtmlDocument(project, chapters);

                return {
                    ok: true,
                    content,
                    extension: "html",
                    mimeType: "text/html;charset=utf-8"
                };

            }

            if (format === "doc") {

                const content = this.buildManuscriptHtmlDocument(project, chapters);

                return {
                    ok: true,
                    content,
                    extension: "doc",
                    mimeType: "application/msword;charset=utf-8"
                };

            }

            return {
                ok: false,
                error: "Unsupported manuscript format."
            };

        }


        buildManuscriptHtmlDocument(project, chapters, options = {}) {

            const pdfOptions = this.normalizePdfExportOptions(options);

            const marginMap = {
                narrow: "0.35in",
                normal: "0.5in",
                wide: "0.85in"
            };

            const pageMargin = marginMap[pdfOptions.margin] || marginMap.normal;

            const chapterBlocks = chapters.map((chapter, index) => {
                const body = this.escapeHTML(String(chapter.content || "")).replace(/\n/g, "<br>");

                if (!pdfOptions.includeChapterTitles) {
                    return `\n<section class="manuscript-chapter">\n  <article>${body}</article>\n</section>`;
                }

                const title = this.escapeHTML(this.getChapterTitle(chapter, index));
                return `\n<section class="manuscript-chapter">\n  <h2>${title}</h2>\n  <article>${body}</article>\n</section>`;
            }).join("\n");

            const title = String(options.titleOverride || this.getProjectTitle(project));

            return `<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1.0">\n<title>${this.escapeHTML(title)}</title>\n<style>@page{size:${this.escapeHTML(pdfOptions.pageSize)};margin:${pageMargin};}body{font-family: Georgia, serif; line-height:1.6; margin:2rem auto; max-width:800px; padding:0 1rem;} h1,h2{line-height:1.2;} .manuscript-chapter{margin:2rem 0;} article{white-space:normal;} @media print{body{max-width:none;margin:0;padding:0;} .manuscript-chapter{break-inside:avoid;}}</style>\n</head>\n<body>\n<h1>${this.escapeHTML(this.getProjectTitle(project))}</h1>${chapterBlocks}\n</body>\n</html>`;

        }


        normalizePdfExportOptions(options = {}) {

            const source = options && typeof options === "object"
                ? options
                : {};

            const pageSize = String(source.pageSize || "A4").trim();
            const margin = String(source.margin || "normal").trim().toLowerCase();

            return {
                pageSize: ["A4", "Letter"].includes(pageSize) ? pageSize : "A4",
                margin: ["narrow", "normal", "wide"].includes(margin) ? margin : "normal",
                includeChapterTitles: source.includeChapterTitles !== false
            };

        }


        openPrintDialogForPdf(content) {

            try {

                if (typeof window === "undefined" || typeof document === "undefined") {
                    return {
                        ok: false,
                        error: "PDF export is unavailable in this runtime."
                    };
                }

                const host = document.body;

                if (!host) {
                    return {
                        ok: false,
                        error: "PDF export is unavailable because the document body is missing."
                    };
                }

                const frame = document.createElement("iframe");

                frame.setAttribute("aria-hidden", "true");
                frame.style.position = "fixed";
                frame.style.right = "0";
                frame.style.bottom = "0";
                frame.style.width = "0";
                frame.style.height = "0";
                frame.style.border = "0";
                frame.style.opacity = "0";

                frame.onload = () => {
                    try {
                        const targetWindow = frame.contentWindow;

                        if (!targetWindow) {
                            return;
                        }

                        targetWindow.focus();
                        targetWindow.print();

                        setTimeout(() => {
                            frame.remove();
                        }, 1200);

                    } catch (error) {
                        console.error("AuthorOS PDF print trigger failed:", error);
                        frame.remove();
                    }
                };

                host.appendChild(frame);
                frame.srcdoc = String(content || "");

                return { ok: true };

            } catch (error) {

                console.error("AuthorOS PDF export failed:", error);

                return {
                    ok: false,
                    error: "PDF export failed in current runtime."
                };

            }

        }


        normalizeManuscriptFormat(format) {
            const value = String(format || "md").trim().toLowerCase();
            return ["txt", "md", "html", "doc", "pdf"].includes(value) ? value : "md";
        }


        async parseBackupFile(file) {

            if (!file) {
                return {
                    ok: false,
                    error: "No file selected."
                };
            }

            const name = String(file.name || "").trim();
            const size = Number(file.size || 0);

            if (!this.allowedImportExtensions.some(extension => name.toLowerCase().endsWith(extension))) {
                return {
                    ok: false,
                    error: "Unsupported file type. Only .json backups are accepted."
                };
            }

            if (size > this.maxImportBytes) {
                return {
                    ok: false,
                    error: `File exceeds ${Math.round(this.maxImportBytes / (1024 * 1024))}MB limit.`
                };
            }

            let raw = "";

            try {
                raw = await this.readFileAsText(file);
            } catch (error) {
                return {
                    ok: false,
                    error: "Unable to read the selected file."
                };
            }

            let parsed = null;

            try {
                parsed = JSON.parse(raw);
            } catch (error) {
                return {
                    ok: false,
                    error: "Invalid JSON file."
                };
            }

            const migrated = this.migrateParsedPayload(parsed);

            if (!migrated.ok) {
                return migrated;
            }

            const validation = this.validateBackupPayload(migrated.payload, { strictRelationships: true });

            if (!validation.ok) {
                return {
                    ok: false,
                    error: "Backup schema validation failed.",
                    validation
                };
            }

            const preview = this.buildImportPreview(migrated.payload, {
                fileName: name,
                fileSize: size
            });

            return {
                ok: true,
                payload: migrated.payload,
                preview,
                validation,
                rawLength: raw.length
            };

        }


        async parseManuscriptImportFile(file) {

            if (!file) {
                return {
                    ok: false,
                    error: "No manuscript file selected."
                };
            }

            const name = String(file.name || "").trim();
            const size = Number(file.size || 0);
            const format = this.normalizeDocumentImportFormat(name);

            if (!format) {
                return {
                    ok: false,
                    error: "Unsupported manuscript file type. Use TXT, Markdown, HTML, or Word (.doc exported from Author Studio)."
                };
            }

            if (size > this.maxDocumentImportBytes) {
                return {
                    ok: false,
                    error: `Document exceeds ${Math.round(this.maxDocumentImportBytes / (1024 * 1024))}MB limit.`
                };
            }

            let raw = "";

            try {
                raw = await this.readFileAsText(file);
            } catch (error) {
                return {
                    ok: false,
                    error: "Unable to read the selected manuscript file."
                };
            }

            const preview = this.buildManuscriptImportPreview(raw, {
                fileName: name,
                fileSize: size,
                format
            });

            if (!preview.ok) {
                return preview;
            }

            return {
                ok: true,
                preview: preview.preview,
                rawLength: raw.length
            };

        }


        buildManuscriptImportPreview(raw, fileInfo = {}) {

            const format = this.normalizeDocumentImportFormat(fileInfo.fileName || fileInfo.format || "");

            if (!format) {
                return {
                    ok: false,
                    error: "Unsupported manuscript file type."
                };
            }

            const extracted = this.extractChaptersFromDocument(raw, {
                fileName: fileInfo.fileName,
                format
            });

            if (!extracted.ok) {
                return extracted;
            }

            const chapters = extracted.chapters.map((chapter, index) => ({
                title: String(chapter.title || `Chapter ${index + 1}`).trim() || `Chapter ${index + 1}`,
                content: String(chapter.content || ""),
                order: index + 1,
                wordCount: this.countWords(chapter.content || "")
            }));

            return {
                ok: true,
                preview: {
                    importType: "manuscript-document",
                    fileName: String(fileInfo.fileName || ""),
                    fileSize: Number(fileInfo.fileSize || 0),
                    format,
                    chapterCount: chapters.length,
                    totalWords: chapters.reduce((sum, chapter) => sum + chapter.wordCount, 0),
                    chapters,
                    warnings: Array.isArray(extracted.warnings) ? extracted.warnings : []
                }
            };

        }


        importParsedManuscript(projectId, preview) {

            const sourcePreview = preview && typeof preview === "object"
                ? preview
                : null;

            if (!sourcePreview || !Array.isArray(sourcePreview.chapters) || !sourcePreview.chapters.length) {
                return {
                    ok: false,
                    error: "No parsed manuscript chapters are available to import."
                };
            }

            const projects = this.cloneData(this.getProjects());

            if (!Array.isArray(projects)) {
                return {
                    ok: false,
                    error: "Projects are unavailable for manuscript import."
                };
            }

            const index = projects.findIndex(project => String(project?.id || "") === String(projectId || ""));

            if (index === -1) {
                return {
                    ok: false,
                    error: "Selected project could not be found for manuscript import."
                };
            }

            const existingProject = this.prepareProjectForExport(projects[index]);
            const manuscript = this.ensureManuscriptShape(existingProject.manuscript);
            const existingChapters = Array.isArray(manuscript.chapters)
                ? manuscript.chapters.filter(chapter => chapter && typeof chapter === "object")
                : [];

            const now = new Date().toISOString();
            const nextChapters = sourcePreview.chapters.map((chapter, chapterIndex) => {
                const content = String(chapter.content || "").trim();
                return {
                    id: AuthorOSHelpers.generateId("chapter"),
                    projectId: existingProject.id,
                    title: String(chapter.title || `Chapter ${existingChapters.length + chapterIndex + 1}`).trim() || `Chapter ${existingChapters.length + chapterIndex + 1}`,
                    order: existingChapters.length + chapterIndex + 1,
                    content,
                    wordCount: this.countWords(content),
                    createdAt: now,
                    updatedAt: now
                };
            });

            const updatedProject = {
                ...existingProject,
                manuscript: {
                    ...manuscript,
                    chapters: [...existingChapters, ...nextChapters],
                    lastOpenedChapterId: manuscript.lastOpenedChapterId || nextChapters[0]?.id || null
                },
                updatedAt: now,
                lastModified: now
            };

            const validation = this.validateProjectData(updatedProject);

            if (!validation.ok) {
                return {
                    ok: false,
                    error: validation.errors[0] || "Imported manuscript data failed project validation.",
                    validation
                };
            }

            projects[index] = updatedProject;

            const saved = this.persistProjects(projects, {
                source: "manuscript-document-import"
            });

            if (!saved.ok) {
                return saved;
            }

            return {
                ok: true,
                projectId: updatedProject.id,
                projectName: this.getProjectTitle(updatedProject),
                importedChapterCount: nextChapters.length,
                importedWordCount: nextChapters.reduce((sum, chapter) => sum + Number(chapter.wordCount || 0), 0)
            };

        }


        migrateParsedPayload(parsed) {

            const data = this.cloneData(parsed);

            if (!data || typeof data !== "object") {
                return {
                    ok: false,
                    error: "Backup payload must be an object."
                };
            }

            if (data && data.snapshot && data.projectId && Number(data.schemaVersion) === 1) {

                const migratedPayload = {
                    formatVersion: "1.0.0",
                    authorOSVersion: this.getAuthorOSVersion(),
                    exportedAt: String(data.createdAt || new Date().toISOString()),
                    scope: "project",
                    metadata: {},
                    data: {
                        projects: [this.prepareProjectForExport(data.snapshot)],
                        ideas: []
                    }
                };

                migratedPayload.metadata = this.buildBackupMetadata(migratedPayload);

                return {
                    ok: true,
                    payload: migratedPayload,
                    migratedFrom: "legacy-project-backup-v1"
                };

            }

            const version = this.normalizeFormatVersion(data.formatVersion);

            if (!version) {
                return {
                    ok: false,
                    error: "Missing backup format version."
                };
            }

            if (!this.supportedFormatVersions.has(version)) {
                return {
                    ok: false,
                    error: `Unsupported backup format version: ${version}.`
                };
            }

            const payload = {
                ...data,
                formatVersion: "1.0.0"
            };

            if (!payload.metadata || typeof payload.metadata !== "object") {
                payload.metadata = this.buildBackupMetadata(payload);
            }

            return {
                ok: true,
                payload,
                migratedFrom: version === "1.0.0" ? null : version
            };

        }


        buildImportPreview(payload, fileInfo = {}) {

            const projects = this.extractProjects(payload);
            const ideas = this.extractIdeas(payload);
            const conflicts = this.detectConflicts(payload);
            const metadata = this.buildBackupMetadata(payload);

            return {
                backupType: payload.scope,
                formatVersion: String(payload.formatVersion || ""),
                authorOSVersion: String(payload.authorOSVersion || ""),
                exportedAt: String(payload.exportedAt || ""),
                fileName: String(fileInfo.fileName || ""),
                fileSize: Number(fileInfo.fileSize || 0),
                projectNames: projects.map(project => this.getProjectTitle(project)),
                counts: {
                    projects: projects.length,
                    ideas: ideas.length,
                    chapters: metadata.counts.chapters,
                    scenes: metadata.counts.plotScenes,
                    characters: metadata.counts.characters,
                    worldEntries: metadata.counts.worldEntries,
                    timelineEvents: metadata.counts.timelineEvents,
                    notesRecords: metadata.counts.notesRecords,
                    notesSources: metadata.counts.notesSources
                },
                conflicts,
                warnings: metadata.warnings || []
            };

        }


        detectConflicts(payload) {

            const existingProjects = this.getProjects();
            const existingIdeas = this.getIdeas();

            const projectById = new Map(existingProjects.map(project => [String(project?.id || ""), project]));
            const projectByName = new Map(existingProjects.map(project => [this.getProjectTitle(project).toLowerCase(), project]));

            const ideaById = new Set(existingIdeas.map(idea => String(idea?.id || "")));

            const projectConflicts = [];

            this.extractProjects(payload).forEach(project => {
                const projectId = String(project?.id || "");
                const projectName = this.getProjectTitle(project);

                const idConflict = projectById.has(projectId);
                const nameConflict = projectByName.has(projectName.toLowerCase());

                if (idConflict || nameConflict) {
                    projectConflicts.push({
                        projectId,
                        projectName,
                        idConflict,
                        nameConflict,
                        existingProjectId: idConflict ? String(projectById.get(projectId)?.id || "") : "",
                        existingProjectName: nameConflict ? this.getProjectTitle(projectByName.get(projectName.toLowerCase())) : ""
                    });
                }
            });

            const ideaConflicts = this.extractIdeas(payload)
                .filter(idea => ideaById.has(String(idea?.id || "")))
                .map(idea => ({
                    ideaId: String(idea?.id || ""),
                    title: String(idea?.title || "Untitled Idea")
                }));

            return {
                hasConflicts: projectConflicts.length > 0 || ideaConflicts.length > 0,
                projectConflicts,
                ideaConflicts
            };

        }


        stageImport(payload, options = {}) {

            const strategy = this.normalizeImportStrategy(options.strategy);
            const validation = this.validateBackupPayload(payload, { strictRelationships: true });

            if (!validation.ok) {
                return {
                    ok: false,
                    error: "Backup failed validation and cannot be imported.",
                    validation
                };
            }

            const existingProjects = this.cloneData(this.getProjects());
            const existingIdeas = this.cloneData(this.getIdeas());

            const nextProjects = Array.isArray(existingProjects) ? existingProjects : [];
            const nextIdeas = Array.isArray(existingIdeas) ? existingIdeas : [];

            const importedProjects = [];
            const importedIdeas = [];
            const skipped = [];
            const warnings = [];
            const replacements = [];

            const incomingProjects = this.extractProjects(payload);
            const incomingIdeas = this.extractIdeas(payload);
            const incomingSettings = this.extractSettings(payload);

            const projectsModule = this.core.registry.get("projects");

            incomingProjects.forEach(incoming => {

                const incomingProject = this.prepareProjectForExport(incoming);

                const id = String(incomingProject?.id || "");
                const name = this.getProjectTitle(incomingProject);

                const conflictIndexById = nextProjects.findIndex(project => String(project?.id || "") === id);
                const conflictIndexByName = nextProjects.findIndex(project => this.getProjectTitle(project).toLowerCase() === name.toLowerCase());

                const hasConflict = conflictIndexById >= 0 || conflictIndexByName >= 0;

                if (!hasConflict) {
                    nextProjects.push(incomingProject);
                    importedProjects.push({
                        projectId: incomingProject.id,
                        projectName: this.getProjectTitle(incomingProject),
                        mode: "added"
                    });
                    return;
                }

                if (strategy === "skip") {
                    skipped.push({
                        entity: "project",
                        id,
                        name,
                        reason: "conflict"
                    });
                    return;
                }

                if (strategy === "replace") {

                    if (payload.scope === "full") {
                        warnings.push("Replace strategy is not applied to full backups; conflicting projects are imported as copies.");
                    } else {

                        const replaceIndex = conflictIndexById >= 0 ? conflictIndexById : conflictIndexByName;
                        const targetProject = nextProjects[replaceIndex];

                        if (projectsModule && typeof projectsModule.createProjectBackup === "function" && targetProject?.id) {
                            const safety = projectsModule.createProjectBackup(targetProject.id, {
                                type: "safety-pre-restore",
                                reason: "Safety Backup Before Replace Import",
                                silent: true,
                                requireCleanProject: false
                            });

                            if (!safety) {
                                warnings.push(`Safety backup could not be created for ${this.getProjectTitle(targetProject)}. Imported as copy instead.`);
                            } else {
                                const replacing = {
                                    ...incomingProject,
                                    id: targetProject.id,
                                    updatedAt: new Date().toISOString(),
                                    lastModified: new Date().toISOString()
                                };

                                nextProjects[replaceIndex] = replacing;

                                replacements.push({
                                    targetProjectId: targetProject.id,
                                    targetProjectName: this.getProjectTitle(targetProject),
                                    sourceProjectName: name
                                });

                                importedProjects.push({
                                    projectId: replacing.id,
                                    projectName: this.getProjectTitle(replacing),
                                    mode: "replaced"
                                });

                                return;
                            }

                        }

                    }

                }

                const copied = this.createProjectCopyWithRemappedIds(incomingProject, nextProjects);

                nextProjects.push(copied.project);
                importedProjects.push({
                    projectId: copied.project.id,
                    projectName: this.getProjectTitle(copied.project),
                    mode: "copied"
                });

                if (copied.warnings.length) {
                    warnings.push(...copied.warnings);
                }

            });

            incomingIdeas.forEach(incomingIdea => {

                const idea = this.prepareIdeaForExport(incomingIdea);
                const id = String(idea?.id || "");
                const index = nextIdeas.findIndex(item => String(item?.id || "") === id);

                if (index === -1) {
                    nextIdeas.push(idea);
                    importedIdeas.push({ id: idea.id, mode: "added" });
                    return;
                }

                if (strategy === "skip") {
                    skipped.push({
                        entity: "idea",
                        id,
                        name: String(idea?.title || "Untitled Idea"),
                        reason: "conflict"
                    });
                    return;
                }

                if (strategy === "replace") {
                    nextIdeas[index] = {
                        ...idea,
                        id: String(nextIdeas[index]?.id || idea.id)
                    };
                    importedIdeas.push({ id: String(nextIdeas[index]?.id || idea.id), mode: "replaced" });
                    return;
                }

                const copiedIdea = this.cloneData(idea);
                copiedIdea.id = this.generateUniqueId("idea", nextIdeas.map(item => item.id));
                copiedIdea.title = this.buildCopiedTitle(String(copiedIdea.title || "Untitled Idea"), nextIdeas.map(item => String(item?.title || "")));
                nextIdeas.push(copiedIdea);
                importedIdeas.push({ id: copiedIdea.id, mode: "copied" });

            });

            return {
                ok: true,
                strategy,
                staged: {
                    projects: nextProjects,
                    ideas: nextIdeas,
                    settings: payload.scope === "full"
                        ? this.prepareSettingsForExport(incomingSettings)
                        : null
                },
                summary: {
                    importedProjects,
                    importedIdeas,
                    skipped,
                    replacements,
                    warnings
                }
            };

        }


        commitImport(stagedResult) {

            if (!stagedResult || !stagedResult.ok || !stagedResult.staged) {
                return {
                    ok: false,
                    error: "No valid staged import is available."
                };
            }

            const previousProjects = this.cloneData(this.getProjects());
            const previousIdeas = this.cloneData(this.getIdeas());
                const previousSettings = this.cloneData(this.getSettings());
            const previousCurrentProject = this.cloneData(this.core.state.get("currentProject"));

            try {

                const saveProjectsOk = this.core.storage.saveProjects(stagedResult.staged.projects);

                if (!saveProjectsOk) {
                    throw new Error("Failed to save imported projects.");
                }

                const saveIdeasOk = this.core.storage.saveIdeas(stagedResult.staged.ideas);

                if (!saveIdeasOk) {
                    throw new Error("Failed to save imported ideas.");
                }

                if (stagedResult.staged.settings) {
                    const saveSettingsOk = this.core.storage.saveSettings(stagedResult.staged.settings);

                    if (!saveSettingsOk) {
                        throw new Error("Failed to save imported settings.");
                    }

                    this.core.state.set("settings", stagedResult.staged.settings);
                    this.core.settingsService?.applySettings?.(stagedResult.staged.settings);
                }

                this.core.state.set("projects", stagedResult.staged.projects);
                this.core.state.set("ideas", stagedResult.staged.ideas);

                const importedProject = stagedResult.summary.importedProjects[0] || null;

                if (importedProject?.projectId) {
                    const selected = stagedResult.staged.projects.find(project => project.id === importedProject.projectId) || null;
                    this.core.state.set("currentProject", selected);
                    this.core.storage.saveActiveProjectId(selected?.id || null);
                } else {
                    this.core.state.set("currentProject", previousCurrentProject || null);
                    this.core.storage.saveActiveProjectId(previousCurrentProject?.id || null);
                }

                this.core.events.emit("storage:changed");
                this.core.events.emit("project:imported", stagedResult.summary);

                return {
                    ok: true,
                    summary: stagedResult.summary
                };

            } catch (error) {

                try {
                    this.core.storage.saveProjects(Array.isArray(previousProjects) ? previousProjects : []);
                    this.core.storage.saveIdeas(Array.isArray(previousIdeas) ? previousIdeas : []);
                    this.core.storage.saveSettings(previousSettings || {});

                    this.core.state.set("projects", Array.isArray(previousProjects) ? previousProjects : []);
                    this.core.state.set("ideas", Array.isArray(previousIdeas) ? previousIdeas : []);
                    this.core.state.set("settings", previousSettings || this.core.settingsService?.loadSettings?.() || {});
                    this.core.state.set("currentProject", previousCurrentProject || null);
                    this.core.storage.saveActiveProjectId(previousCurrentProject?.id || null);
                    this.core.settingsService?.applySettings?.(this.core.state.get("settings"));
                } catch (rollbackError) {
                    console.error("AuthorOS import rollback failed:", rollbackError);
                }

                return {
                    ok: false,
                    error: error.message || "Import commit failed."
                };

            }

        }


        normalizeImportStrategy(strategy) {
            const value = String(strategy || "copy").trim().toLowerCase();
            return ["copy", "skip", "replace"].includes(value) ? value : "copy";
        }


        createProjectCopyWithRemappedIds(project, existingProjects) {

            const now = new Date().toISOString();
            const cloned = this.cloneData(project) || {};

            const warnings = [];

            const usedProjectIds = existingProjects.map(item => String(item?.id || ""));
            const newProjectId = this.generateUniqueId("project", usedProjectIds);

            const idMaps = {
                project: new Map([[String(cloned.id || ""), newProjectId]]),
                chapter: new Map(),
                character: new Map(),
                world: new Map(),
                plotArc: new Map(),
                plotAct: new Map(),
                plotBeat: new Map(),
                plotThread: new Map(),
                plotScene: new Map(),
                timelineEvent: new Map(),
                timelineEra: new Map(),
                timelineSequence: new Map(),
                source: new Map(),
                noteRecord: new Map()
            };

            const chapterIdsInUse = new Set();
            const characterIdsInUse = new Set();
            const worldIdsInUse = new Set();
            const plotArcIdsInUse = new Set();
            const plotActIdsInUse = new Set();
            const plotBeatIdsInUse = new Set();
            const plotThreadIdsInUse = new Set();
            const plotSceneIdsInUse = new Set();
            const timelineEventIdsInUse = new Set();
            const timelineEraIdsInUse = new Set();
            const timelineSequenceIdsInUse = new Set();
            const sourceIdsInUse = new Set();
            const noteRecordIdsInUse = new Set();

            cloned.manuscript = this.ensureManuscriptShape(cloned.manuscript);
            cloned.story = this.ensureStoryShape(cloned.story);

            cloned.manuscript.chapters = cloned.manuscript.chapters.map((chapter, index) => {
                const oldId = String(chapter?.id || `chapter-${index + 1}`);
                const newId = this.generateUniqueId("chapter", Array.from(chapterIdsInUse));
                chapterIdsInUse.add(newId);
                idMaps.chapter.set(oldId, newId);
                return {
                    ...chapter,
                    id: newId
                };
            });

            cloned.story.characters = cloned.story.characters.map((character, index) => {
                const oldId = String(character?.id || `character-${index + 1}`);
                const newId = this.generateUniqueId("character", Array.from(characterIdsInUse));
                characterIdsInUse.add(newId);
                idMaps.character.set(oldId, newId);
                return {
                    ...character,
                    id: newId
                };
            });

            cloned.story.worldEntries = cloned.story.worldEntries.map((entry, index) => {
                const oldId = String(entry?.id || `world-${index + 1}`);
                const newId = this.generateUniqueId("world", Array.from(worldIdsInUse));
                worldIdsInUse.add(newId);
                idMaps.world.set(oldId, newId);
                return {
                    ...entry,
                    id: newId
                };
            });

            const plot = cloned.story.plot;

            plot.arcs = plot.arcs.map((arc, index) => {
                const oldId = String(arc?.id || `plot-arc-${index + 1}`);
                const newId = this.generateUniqueId("plot_arc", Array.from(plotArcIdsInUse));
                plotArcIdsInUse.add(newId);
                idMaps.plotArc.set(oldId, newId);
                return {
                    ...arc,
                    id: newId
                };
            });

            plot.acts = plot.acts.map((act, index) => {
                const oldId = String(act?.id || `plot-act-${index + 1}`);
                const newId = this.generateUniqueId("plot_act", Array.from(plotActIdsInUse));
                plotActIdsInUse.add(newId);
                idMaps.plotAct.set(oldId, newId);
                return {
                    ...act,
                    id: newId
                };
            });

            plot.beats = plot.beats.map((beat, index) => {
                const oldId = String(beat?.id || `plot-beat-${index + 1}`);
                const newId = this.generateUniqueId("plot_beat", Array.from(plotBeatIdsInUse));
                plotBeatIdsInUse.add(newId);
                idMaps.plotBeat.set(oldId, newId);
                return {
                    ...beat,
                    id: newId
                };
            });

            plot.threads = plot.threads.map((thread, index) => {
                const oldId = String(thread?.id || `plot-thread-${index + 1}`);
                const newId = this.generateUniqueId("plot_thread", Array.from(plotThreadIdsInUse));
                plotThreadIdsInUse.add(newId);
                idMaps.plotThread.set(oldId, newId);
                return {
                    ...thread,
                    id: newId
                };
            });

            plot.scenes = plot.scenes.map((scene, index) => {
                const oldId = String(scene?.id || `plot-scene-${index + 1}`);
                const newId = this.generateUniqueId("plot_scene", Array.from(plotSceneIdsInUse));
                plotSceneIdsInUse.add(newId);
                idMaps.plotScene.set(oldId, newId);

                const chapterId = String(scene?.chapterId || "");
                const remappedChapterId = chapterId && idMaps.chapter.has(chapterId)
                    ? idMaps.chapter.get(chapterId)
                    : chapterId;

                return {
                    ...scene,
                    id: newId,
                    chapterId: remappedChapterId
                };
            });

            const timeline = cloned.story.timeline;

            timeline.eras = timeline.eras.map((era, index) => {
                const oldId = String(era?.id || `timeline-era-${index + 1}`);
                const newId = this.generateUniqueId("timeline_era", Array.from(timelineEraIdsInUse));
                timelineEraIdsInUse.add(newId);
                idMaps.timelineEra.set(oldId, newId);
                return {
                    ...era,
                    id: newId
                };
            });

            timeline.sequences = timeline.sequences.map((sequence, index) => {
                const oldId = String(sequence?.id || `timeline-sequence-${index + 1}`);
                const newId = this.generateUniqueId("timeline_sequence", Array.from(timelineSequenceIdsInUse));
                timelineSequenceIdsInUse.add(newId);
                idMaps.timelineSequence.set(oldId, newId);
                return {
                    ...sequence,
                    id: newId
                };
            });

            timeline.events = timeline.events.map((event, index) => {
                const oldId = String(event?.id || `timeline-event-${index + 1}`);
                const newId = this.generateUniqueId("timeline_event", Array.from(timelineEventIdsInUse));
                timelineEventIdsInUse.add(newId);
                idMaps.timelineEvent.set(oldId, newId);
                return {
                    ...event,
                    id: newId
                };
            });

            const notes = cloned.story.notesStudio;

            notes.sources = notes.sources.map((source, index) => {
                const oldId = String(source?.id || `source-${index + 1}`);
                const newId = this.generateUniqueId("source", Array.from(sourceIdsInUse));
                sourceIdsInUse.add(newId);
                idMaps.source.set(oldId, newId);
                return {
                    ...source,
                    id: newId,
                    projectId: newProjectId
                };
            });

            notes.records = notes.records.map((record, index) => {
                const oldId = String(record?.id || `note-record-${index + 1}`);
                const newId = this.generateUniqueId("note_record", Array.from(noteRecordIdsInUse));
                noteRecordIdsInUse.add(newId);
                idMaps.noteRecord.set(oldId, newId);

                const sourceIds = (Array.isArray(record?.sourceIds) ? record.sourceIds : [])
                    .map(sourceId => idMaps.source.get(String(sourceId || "")) || "")
                    .filter(Boolean);

                const linkedEntityIds = (Array.isArray(record?.linkedEntityIds) ? record.linkedEntityIds : [])
                    .map(token => this.remapLinkedEntityToken(token, idMaps))
                    .filter(Boolean);

                return {
                    ...record,
                    id: newId,
                    projectId: newProjectId,
                    sourceIds,
                    linkedEntityIds
                };
            });

            const usedProjectNames = existingProjects.map(item => this.getProjectTitle(item));

            cloned.id = newProjectId;
            cloned.name = this.buildCopiedTitle(this.getProjectTitle(cloned), usedProjectNames);
            cloned.title = cloned.name;
            cloned.updatedAt = now;
            cloned.lastModified = now;
            cloned.lastOpened = null;

            if (cloned.statistics) {
                delete cloned.statistics;
            }

            const validation = this.validateProjectData(cloned);

            if (!validation.ok) {
                warnings.push(...validation.errors);
            }

            return {
                project: cloned,
                warnings
            };

        }


        remapLinkedEntityToken(token, idMaps) {

            const raw = String(token || "").trim();

            if (!raw || !raw.includes(":")) {
                return "";
            }

            const splitIndex = raw.indexOf(":");
            const kind = raw.slice(0, splitIndex);
            const id = raw.slice(splitIndex + 1);

            if (!kind || !id) {
                return "";
            }

            const map = idMaps[kind];

            if (!map || typeof map.get !== "function") {
                return "";
            }

            const mappedId = map.get(String(id));

            return mappedId ? `${kind}:${mappedId}` : "";

        }


        validateBackupPayload(payload, options = {}) {

            const errors = [];
            const warnings = [];

            if (!payload || typeof payload !== "object") {
                errors.push("Backup root must be an object.");
                return { ok: false, errors, warnings };
            }

            const formatVersion = this.normalizeFormatVersion(payload.formatVersion);

            if (!formatVersion) {
                errors.push("Backup is missing formatVersion.");
            } else if (!this.supportedFormatVersions.has(formatVersion)) {
                errors.push(`Unsupported backup format version: ${formatVersion}.`);
            }

            const scope = String(payload.scope || "").trim();
            const validScopes = ["full", "project", "structured-project"];

            if (!validScopes.includes(scope)) {
                errors.push("Backup scope is invalid.");
            }

            const exportedAt = new Date(String(payload.exportedAt || ""));

            if (Number.isNaN(exportedAt.getTime())) {
                errors.push("Backup exportedAt value is invalid.");
            }

            if (!payload.data || typeof payload.data !== "object") {
                errors.push("Backup data object is required.");
            }

            const projects = this.extractProjects(payload);
            const ideas = this.extractIdeas(payload);
            const settings = this.extractSettings(payload);

            if (scope === "project" || scope === "structured-project") {
                if (projects.length !== 1) {
                    errors.push("Project-scope backups must include exactly one project.");
                }
            }

            const projectIds = new Set();

            projects.forEach(project => {
                const id = String(project?.id || "").trim();

                if (!id) {
                    errors.push("Every project must have a valid id.");
                    return;
                }

                if (projectIds.has(id)) {
                    errors.push(`Duplicate project id detected: ${id}.`);
                }

                projectIds.add(id);

                const validation = this.validateProjectData(project, options);

                if (!validation.ok) {
                    validation.errors.forEach(error => errors.push(error));
                }

                validation.warnings.forEach(warning => warnings.push(warning));
            });

            const ideaIds = new Set();

            ideas.forEach(idea => {
                const id = String(idea?.id || "").trim();
                if (!id) {
                    errors.push("Every idea must have a valid id.");
                    return;
                }

                if (ideaIds.has(id)) {
                    errors.push(`Duplicate idea id detected: ${id}.`);
                }

                ideaIds.add(id);
            });

            if (scope === "full") {

                if (!("settings" in payload.data)) {
                    errors.push("Full backups must include settings.");
                }

                const settingsValidation = this.validateSettingsData(settings);

                if (!settingsValidation.ok) {
                    settingsValidation.errors.forEach(error => errors.push(error));
                }

                settingsValidation.warnings.forEach(warning => warnings.push(warning));

            }

            return {
                ok: errors.length === 0,
                errors,
                warnings
            };

        }


        validateSettingsData(settings) {

            const errors = [];
            const warnings = [];

            if (!settings || typeof settings !== "object" || Array.isArray(settings)) {
                errors.push("Settings payload must be an object.");
                return { ok: false, errors, warnings };
            }

            const requiredTopLevelKeys = [
                "settingsVersion",
                "appearance",
                "editor",
                "application",
                "notifications",
                "accessibility",
                "shortcuts",
                "data",
                "updatedAt"
            ];

            requiredTopLevelKeys.forEach(key => {
                if (!(key in settings)) {
                    errors.push(`Settings payload is missing required key "${key}".`);
                }
            });

            const dashboardBackground = settings?.appearance?.dashboardBackground;

            if (!dashboardBackground || typeof dashboardBackground !== "object" || Array.isArray(dashboardBackground)) {
                errors.push("Settings appearance.dashboardBackground must be an object.");
            } else {

                const position = String(dashboardBackground.position || "").trim();
                const size = String(dashboardBackground.size || "").trim();

                if (!["center", "top", "bottom", "left", "right"].includes(position)) {
                    errors.push("Settings appearance.dashboardBackground.position is invalid.");
                }

                if (!["cover", "contain", "auto"].includes(size)) {
                    errors.push("Settings appearance.dashboardBackground.size is invalid.");
                }

                if (window.AuthorOSImageAssets) {
                    const normalizedImage = window.AuthorOSImageAssets.normalizeStoredAsset(
                        dashboardBackground.image,
                        {
                            maxStoredBytes: 2 * 1024 * 1024
                        }
                    );

                    const hasRawImage = Boolean(dashboardBackground.image);
                    const hasNormalizedImage = Boolean(normalizedImage?.dataUrl);

                    if (hasRawImage && !hasNormalizedImage) {
                        errors.push("Settings appearance.dashboardBackground.image is invalid or unsupported.");
                    }
                }

            }

            if (this.core.settingsService && typeof this.core.settingsService.normalizeSettings === "function") {
                const normalized = this.core.settingsService.normalizeSettings(settings);

                if (!normalized || typeof normalized !== "object") {
                    errors.push("Settings payload normalization failed.");
                }
            } else {
                warnings.push("Settings service normalizeSettings is unavailable; strict schema checks are limited.");
            }

            return {
                ok: errors.length === 0,
                errors,
                warnings
            };

        }


        validateProjectData(project, options = {}) {

            const errors = [];
            const warnings = [];

            const projectId = String(project?.id || "").trim();
            const projectName = this.getProjectTitle(project);

            if (!projectId) {
                errors.push("Project id is required.");
            }

            if (!projectName) {
                errors.push("Project title is required.");
            }

            const normalized = this.prepareProjectForExport(project);

            const chapters = this.getProjectChapters(normalized);
            const characters = this.getProjectCharacters(normalized);
            const worldEntries = this.getProjectWorldEntries(normalized);
            const plot = this.getProjectPlot(normalized);
            const timeline = this.getProjectTimeline(normalized);
            const notes = this.getProjectNotesStudio(normalized);

            const chapterIds = this.collectUniqueIdMap(chapters, "Chapter", errors);
            const characterIds = this.collectUniqueIdMap(characters, "Character", errors);
            const worldIds = this.collectUniqueIdMap(worldEntries, "World entry", errors);
            const arcIds = this.collectUniqueIdMap(plot.arcs, "Plot arc", errors);
            const actIds = this.collectUniqueIdMap(plot.acts, "Plot act", errors);
            const beatIds = this.collectUniqueIdMap(plot.beats, "Plot beat", errors);
            const threadIds = this.collectUniqueIdMap(plot.threads, "Plot thread", errors);
            const sceneIds = this.collectUniqueIdMap(plot.scenes, "Plot scene", errors);
            const eventIds = this.collectUniqueIdMap(timeline.events, "Timeline event", errors);
            const eraIds = this.collectUniqueIdMap(timeline.eras, "Timeline era", errors);
            const sequenceIds = this.collectUniqueIdMap(timeline.sequences, "Timeline sequence", errors);
            const sourceIds = this.collectUniqueIdMap(notes.sources, "Notes source", errors);
            this.collectUniqueIdMap(notes.records, "Notes record", errors);

            plot.scenes.forEach(scene => {
                const chapterId = String(scene?.chapterId || "").trim();
                if (chapterId && !chapterIds.has(chapterId)) {
                    errors.push(`Project "${projectName}" has a scene referencing missing chapter id "${chapterId}".`);
                }
            });

            notes.records.forEach(record => {
                const linkedSourceIds = Array.isArray(record?.sourceIds) ? record.sourceIds : [];

                linkedSourceIds.forEach(sourceId => {
                    const id = String(sourceId || "").trim();
                    if (id && !sourceIds.has(id)) {
                        errors.push(`Project "${projectName}" has a notes record referencing missing source id "${id}".`);
                    }
                });

                const tokens = Array.isArray(record?.linkedEntityIds) ? record.linkedEntityIds : [];

                tokens.forEach(token => {
                    const parsed = this.parseEntityToken(token);

                    if (!parsed) {
                        errors.push(`Project "${projectName}" has invalid linked entity token "${String(token || "")}".`);
                        return;
                    }

                    const { kind, id } = parsed;

                    if (kind === "project" && id === projectId) {
                        return;
                    }

                    if (kind === "chapter" && chapterIds.has(id)) {
                        return;
                    }

                    if (kind === "character" && characterIds.has(id)) {
                        return;
                    }

                    if (kind === "world" && worldIds.has(id)) {
                        return;
                    }

                    if (kind === "plotArc" && arcIds.has(id)) {
                        return;
                    }

                    if (kind === "plotAct" && actIds.has(id)) {
                        return;
                    }

                    if (kind === "plotBeat" && beatIds.has(id)) {
                        return;
                    }

                    if (kind === "plotThread" && threadIds.has(id)) {
                        return;
                    }

                    if (kind === "plotScene" && sceneIds.has(id)) {
                        return;
                    }

                    if (kind === "timelineEvent" && eventIds.has(id)) {
                        return;
                    }

                    if (kind === "timelineEra" && eraIds.has(id)) {
                        return;
                    }

                    if (kind === "timelineSequence" && sequenceIds.has(id)) {
                        return;
                    }

                    errors.push(`Project "${projectName}" has linked entity token "${kind}:${id}" with missing target.`);
                });
            });

            if (!options.strictRelationships) {
                while (errors.length) {
                    warnings.push(errors.shift());
                }
            }

            return {
                ok: errors.length === 0,
                errors,
                warnings
            };

        }


        collectUniqueIdMap(items, label, errors) {

            const ids = new Set();

            (Array.isArray(items) ? items : []).forEach((item, index) => {
                const id = String(item?.id || "").trim();

                if (!id) {
                    errors.push(`${label} at index ${index + 1} is missing an id.`);
                    return;
                }

                if (ids.has(id)) {
                    errors.push(`${label} id "${id}" is duplicated.`);
                    return;
                }

                ids.add(id);
            });

            return ids;

        }


        prepareProjectForExport(project) {

            const cloned = this.cloneData(project) || {};

            const now = new Date().toISOString();

            const prepared = {
                id: String(cloned.id || "").trim(),
                name: this.getProjectTitle(cloned),
                title: this.getProjectTitle(cloned),
                description: String(cloned.description || ""),
                type: String(cloned.type || "Novel").trim() || "Novel",
                genre: String(cloned.genre || "").trim(),
                genreTags: Array.isArray(cloned.genreTags)
                    ? cloned.genreTags.map(tag => String(tag || "").trim()).filter(Boolean)
                    : (String(cloned.genre || "").trim() ? [String(cloned.genre || "").trim()] : []),
                status: String(cloned.status || "Draft").trim() || "Draft",
                series: String(cloned.series || "").trim(),
                author: String(cloned.author || "").trim(),
                targetWords: this.toSafeNumber(cloned.targetWords ?? cloned.targetWordCount, 100000),
                targetWordCount: this.toSafeNumber(cloned.targetWords ?? cloned.targetWordCount, 100000),
                createdAt: this.normalizeDate(cloned.createdAt, now),
                updatedAt: this.normalizeDate(cloned.updatedAt || cloned.lastModified, now),
                lastModified: this.normalizeDate(cloned.lastModified || cloned.updatedAt, now),
                image: window.AuthorOSImageAssets
                    ? window.AuthorOSImageAssets.normalizeStoredAsset(
                        cloned.image,
                        {
                            maxStoredBytes: 1024 * 1024
                        }
                    )
                    : null,
                manuscript: this.ensureManuscriptShape(cloned.manuscript),
                story: this.ensureStoryShape(cloned.story)
            };

            return prepared;

        }


        prepareIdeaForExport(idea) {

            const cloned = this.cloneData(idea) || {};
            const now = new Date().toISOString();

            return {
                id: String(cloned.id || "").trim(),
                title: String(cloned.title || cloned.name || "Untitled Idea").trim() || "Untitled Idea",
                summary: String(cloned.summary || ""),
                content: String(cloned.content || cloned.description || ""),
                tags: Array.isArray(cloned.tags) ? cloned.tags.map(tag => String(tag || "").trim()).filter(Boolean) : [],
                category: String(cloned.category || "General").trim() || "General",
                status: String(cloned.status || "Draft").trim() || "Draft",
                createdAt: this.normalizeDate(cloned.createdAt, now),
                updatedAt: this.normalizeDate(cloned.updatedAt || cloned.lastModified, now)
            };

        }


        ensureStoryShape(story) {

            const source = story && typeof story === "object" ? story : {};

            const normalizedTimeline = this.ensureTimelineShape(source.timeline);

            return {
                characters: Array.isArray(source.characters) ? source.characters.filter(item => item && typeof item === "object") : [],
                worldEntries: Array.isArray(source.worldEntries) ? source.worldEntries.filter(item => item && typeof item === "object") : [],
                plot: this.ensurePlotShape(source.plot),
                timeline: normalizedTimeline,
                notesStudio: this.ensureNotesStudioShape(source.notesStudio)
            };

        }


        ensureManuscriptShape(manuscript) {
            const source = manuscript && typeof manuscript === "object" ? manuscript : {};
            return {
                chapters: Array.isArray(source.chapters) ? source.chapters.filter(chapter => chapter && typeof chapter === "object") : [],
                goalTargetWords: this.toSafeNumber(source.goalTargetWords, this.toSafeNumber(source.targetWords, 0))
            };
        }


        ensurePlotShape(plot) {

            const source = plot && typeof plot === "object" ? plot : {};

            return {
                arcs: Array.isArray(source.arcs) ? source.arcs.filter(item => item && typeof item === "object") : [],
                acts: Array.isArray(source.acts) ? source.acts.filter(item => item && typeof item === "object") : [],
                beats: Array.isArray(source.beats) ? source.beats.filter(item => item && typeof item === "object") : [],
                threads: Array.isArray(source.threads) ? source.threads.filter(item => item && typeof item === "object") : [],
                scenes: Array.isArray(source.scenes) ? source.scenes.filter(item => item && typeof item === "object") : []
            };

        }


        ensureTimelineShape(timeline) {

            if (Array.isArray(timeline)) {
                return {
                    eras: [],
                    sequences: [],
                    events: timeline.filter(item => item && typeof item === "object")
                };
            }

            const source = timeline && typeof timeline === "object" ? timeline : {};

            return {
                eras: Array.isArray(source.eras) ? source.eras.filter(item => item && typeof item === "object") : [],
                sequences: Array.isArray(source.sequences) ? source.sequences.filter(item => item && typeof item === "object") : [],
                events: Array.isArray(source.events) ? source.events.filter(item => item && typeof item === "object") : []
            };

        }


        ensureNotesStudioShape(notesStudio) {

            const source = notesStudio && typeof notesStudio === "object" ? notesStudio : {};

            return {
                records: Array.isArray(source.records) ? source.records.filter(item => item && typeof item === "object") : [],
                sources: Array.isArray(source.sources) ? source.sources.filter(item => item && typeof item === "object") : []
            };

        }


        buildBackupMetadata(payload) {

            const projects = this.extractProjects(payload);
            const ideas = this.extractIdeas(payload);

            const counts = projects.reduce((acc, project) => {

                const chapters = this.getProjectChapters(project);
                const plot = this.getProjectPlot(project);
                const timeline = this.getProjectTimeline(project);
                const notes = this.getProjectNotesStudio(project);

                acc.projects += 1;
                acc.chapters += chapters.length;
                acc.characters += this.getProjectCharacters(project).length;
                acc.worldEntries += this.getProjectWorldEntries(project).length;
                acc.plotArcs += plot.arcs.length;
                acc.plotActs += plot.acts.length;
                acc.plotBeats += plot.beats.length;
                acc.plotThreads += plot.threads.length;
                acc.plotScenes += plot.scenes.length;
                acc.timelineEvents += timeline.events.length;
                acc.timelineEras += timeline.eras.length;
                acc.timelineSequences += timeline.sequences.length;
                acc.notesRecords += notes.records.length;
                acc.notesSources += notes.sources.length;
                acc.words += chapters.reduce((sum, chapter) => sum + this.countWords(String(chapter?.content || "")), 0);

                return acc;

            }, {
                projects: 0,
                ideas: ideas.length,
                chapters: 0,
                characters: 0,
                worldEntries: 0,
                plotArcs: 0,
                plotActs: 0,
                plotBeats: 0,
                plotThreads: 0,
                plotScenes: 0,
                timelineEvents: 0,
                timelineEras: 0,
                timelineSequences: 0,
                notesRecords: 0,
                notesSources: 0,
                words: 0
            });

            return {
                backupType: String(payload.scope || ""),
                formatVersion: String(payload.formatVersion || this.formatVersion),
                authorOSVersion: String(payload.authorOSVersion || this.getAuthorOSVersion()),
                createdDate: String(payload.exportedAt || new Date().toISOString()),
                counts,
                warnings: []
            };

        }


        readFileAsText(file) {

            return new Promise((resolve, reject) => {

                if (file && typeof file.text === "function") {
                    file.text()
                        .then(text => {
                            resolve(String(text || ""));
                        })
                        .catch(() => {
                            reject(new Error("Unable to read file."));
                        });
                    return;
                }

                if (typeof FileReader !== "function") {
                    reject(new Error("FileReader is unavailable in this runtime."));
                    return;
                }

                const reader = new FileReader();

                reader.onload = () => {
                    resolve(String(reader.result || ""));
                };

                reader.onerror = () => {
                    reject(new Error("Unable to read file."));
                };

                reader.readAsText(file);

            });

        }


        extractChaptersFromDocument(raw, options = {}) {

            const format = this.normalizeDocumentImportFormat(options.fileName || options.format || "");
            const source = String(raw || "");
            const warnings = [];
            const fallbackTitle = this.buildImportFallbackTitle(options.fileName || "Imported Manuscript");

            if (!source.trim()) {
                return {
                    ok: false,
                    error: "Selected manuscript file is empty."
                };
            }

            if (format === "html" || format === "doc") {
                const extractedFromHtml = this.extractHtmlDocumentChapters(source, fallbackTitle);

                if (format === "doc") {
                    warnings.push("Word import expects HTML-backed .doc files, such as Author Studio Word exports.");
                }

                return {
                    ok: true,
                    chapters: extractedFromHtml.chapters,
                    warnings: [...warnings, ...extractedFromHtml.warnings]
                };
            }

            if (format === "md") {
                const markdownChapters = this.extractMarkdownChapters(source, fallbackTitle);
                return {
                    ok: true,
                    chapters: markdownChapters.chapters,
                    warnings: markdownChapters.warnings
                };
            }

            const textChapters = this.extractPlainTextChapters(source, fallbackTitle);

            return {
                ok: true,
                chapters: textChapters.chapters,
                warnings: textChapters.warnings
            };

        }


        extractMarkdownChapters(raw, fallbackTitle) {

            const lines = String(raw || "").replace(/\r\n?/g, "\n").split("\n");
            const chapterHeadingIndexes = [];

            lines.forEach((line, index) => {
                if (/^##\s+.+$/.test(line.trim())) {
                    chapterHeadingIndexes.push(index);
                }
            });

            if (!chapterHeadingIndexes.length) {
                lines.forEach((line, index) => {
                    if (/^#\s+.+$/.test(line.trim())) {
                        chapterHeadingIndexes.push(index);
                    }
                });
            }

            if (!chapterHeadingIndexes.length) {
                return {
                    chapters: [{ title: fallbackTitle, content: String(raw || "").trim() }],
                    warnings: ["No Markdown chapter headings were detected. Imported as a single chapter."]
                };
            }

            const chapters = [];

            chapterHeadingIndexes.forEach((startIndex, listIndex) => {
                const endIndex = listIndex + 1 < chapterHeadingIndexes.length
                    ? chapterHeadingIndexes[listIndex + 1]
                    : lines.length;

                const heading = lines[startIndex].replace(/^#{1,6}\s+/, "").trim();
                const body = lines.slice(startIndex + 1, endIndex).join("\n").trim();

                chapters.push({
                    title: heading || `Chapter ${listIndex + 1}`,
                    content: body
                });
            });

            return {
                chapters: chapters.filter(chapter => chapter.title || chapter.content),
                warnings: []
            };

        }


        extractPlainTextChapters(raw, fallbackTitle) {

            const lines = String(raw || "").replace(/\r\n?/g, "\n").split("\n");
            const headingIndexes = [];

            lines.forEach((line, index) => {
                if (/^\s*(chapter\s+[\w\d-]+.*|prologue|epilogue)\s*$/i.test(line.trim())) {
                    headingIndexes.push(index);
                }
            });

            if (!headingIndexes.length) {
                return {
                    chapters: [{ title: fallbackTitle, content: String(raw || "").trim() }],
                    warnings: ["No chapter-style headings were detected. Imported as a single chapter."]
                };
            }

            const chapters = [];

            headingIndexes.forEach((startIndex, listIndex) => {
                const endIndex = listIndex + 1 < headingIndexes.length
                    ? headingIndexes[listIndex + 1]
                    : lines.length;

                const title = String(lines[startIndex] || "").trim() || `Chapter ${listIndex + 1}`;
                const content = lines.slice(startIndex + 1, endIndex).join("\n").trim();

                chapters.push({ title, content });
            });

            return {
                chapters: chapters.filter(chapter => chapter.title || chapter.content),
                warnings: []
            };

        }


        extractHtmlDocumentChapters(raw, fallbackTitle) {

            if (typeof DOMParser !== "function") {
                return {
                    chapters: [{ title: fallbackTitle, content: this.stripHtml(String(raw || "")).trim() }],
                    warnings: ["HTML parser is unavailable in this runtime. Imported as a single chapter."]
                };
            }

            const parser = new DOMParser();
            const documentNode = parser.parseFromString(String(raw || ""), "text/html");
            const sectionNodes = Array.from(documentNode.querySelectorAll(".manuscript-chapter"));

            if (sectionNodes.length) {
                return {
                    chapters: sectionNodes.map((section, index) => ({
                        title: String(section.querySelector("h1, h2, h3, h4, h5, h6")?.textContent || `Chapter ${index + 1}`).trim() || `Chapter ${index + 1}`,
                        content: String(section.querySelector("article")?.textContent || section.textContent || "").trim()
                    })).filter(chapter => chapter.title || chapter.content),
                    warnings: []
                };
            }

            const text = String(documentNode.body?.textContent || this.stripHtml(String(raw || ""))).trim();

            return {
                chapters: [{ title: fallbackTitle, content: text }],
                warnings: ["HTML document did not contain chapter section markers. Imported as a single chapter."]
            };

        }


        normalizeDocumentImportFormat(fileName) {

            const lower = String(fileName || "").trim().toLowerCase();

            if (lower.endsWith(".md") || lower.endsWith(".markdown")) {
                return "md";
            }

            if (lower.endsWith(".txt")) {
                return "txt";
            }

            if (lower.endsWith(".html") || lower.endsWith(".htm")) {
                return "html";
            }

            if (lower.endsWith(".doc")) {
                return "doc";
            }

            return "";

        }


        buildImportFallbackTitle(fileName) {

            const baseName = String(fileName || "Imported Manuscript")
                .replace(/\.[^.]+$/, "")
                .replace(/[_-]+/g, " ")
                .trim();

            return baseName || "Imported Manuscript";

        }


        stripHtml(value) {
            return String(value || "").replace(/<[^>]*>/g, " ");
        }


        persistProjects(projects, options = {}) {

            const projectsModule = this.core.registry.get("projects");

            if (projectsModule && typeof projectsModule.saveProjects === "function") {
                const saved = projectsModule.saveProjects(projects, {
                    source: options.source || "backup-export"
                });

                return saved
                    ? { ok: true }
                    : { ok: false, error: "Project storage write failed." };
            }

            try {
                const saved = this.core.storage.saveProjects(projects);

                if (!saved) {
                    return {
                        ok: false,
                        error: "Project storage write failed."
                    };
                }

                this.core.state.set("projects", projects);

                const currentProject = projects.find(project => project.id === this.core.state.get("currentProject")?.id) || null;
                this.core.state.set("currentProject", currentProject);
                this.core.storage.saveActiveProjectId(currentProject?.id || null);
                this.core.events.emit("storage:changed");

                return { ok: true };

            } catch (error) {

                console.error("AuthorOS manuscript import persistence failed:", error);

                return {
                    ok: false,
                    error: "Project storage write failed."
                };

            }

        }


        normalizeFormatVersion(version) {

            const value = String(version ?? "").trim();

            if (!value) {
                return "";
            }

            if (value === "1" || value === "1.0" || value === "1.0.0") {
                return value === "1.0.0" ? "1.0.0" : "1";
            }

            return value;

        }


        extractProjects(payload) {
            const projects = payload?.data?.projects;
            return Array.isArray(projects) ? projects : [];
        }


        extractIdeas(payload) {
            const ideas = payload?.data?.ideas;
            return Array.isArray(ideas) ? ideas : [];
        }


        extractSettings(payload) {
            const settings = payload?.data?.settings;
            return settings && typeof settings === "object" ? settings : {};
        }


        getProjects() {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects) ? projects : [];
        }


        getIdeas() {
            const ideas = this.core.state.get("ideas");
            return Array.isArray(ideas) ? ideas : [];
        }


        getSettings() {
            const settings = this.core.state.get("settings");
            return settings && typeof settings === "object" ? settings : this.core.settingsService?.loadSettings?.() || {};
        }


        prepareSettingsForExport(settings) {
            const source = settings && typeof settings === "object"
                ? this.cloneData(settings)
                : {};

            if (this.core.settingsService && typeof this.core.settingsService.normalizeSettings === "function") {
                return this.core.settingsService.normalizeSettings(source);
            }

            return source;
        }


        getProjectTitle(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        }


        getChapterTitle(chapter, index) {
            return String(chapter?.title || `Chapter ${index + 1}`).trim() || `Chapter ${index + 1}`;
        }


        getProjectChapters(project) {
            return Array.isArray(project?.manuscript?.chapters) ? project.manuscript.chapters : [];
        }


        getProjectCharacters(project) {
            return Array.isArray(project?.story?.characters) ? project.story.characters : [];
        }


        getProjectWorldEntries(project) {
            return Array.isArray(project?.story?.worldEntries) ? project.story.worldEntries : [];
        }


        getProjectPlot(project) {
            return this.ensurePlotShape(project?.story?.plot);
        }


        getProjectTimeline(project) {
            return this.ensureTimelineShape(project?.story?.timeline);
        }


        getProjectNotesStudio(project) {
            return this.ensureNotesStudioShape(project?.story?.notesStudio);
        }


        parseEntityToken(token) {

            const raw = String(token || "").trim();

            if (!raw || !raw.includes(":")) {
                return null;
            }

            const index = raw.indexOf(":");
            const kind = raw.slice(0, index);
            const id = raw.slice(index + 1);

            if (!kind || !id) {
                return null;
            }

            return {
                kind,
                id
            };

        }


        toSafeNumber(value, fallback = 0) {
            const number = Number(value);
            return Number.isFinite(number) ? Math.max(0, Math.trunc(number)) : fallback;
        }


        normalizeDate(value, fallback) {
            const parsed = new Date(value || "");
            return Number.isNaN(parsed.getTime()) ? fallback : parsed.toISOString();
        }


        countWords(content) {
            const text = String(content || "").trim();
            if (!text) {
                return 0;
            }
            return text.split(/\s+/).filter(Boolean).length;
        }


        generateUniqueId(prefix, existing) {

            const taken = new Set((Array.isArray(existing) ? existing : []).map(value => String(value || "")).filter(Boolean));

            let id = "";

            do {
                id = AuthorOSHelpers.generateId(prefix);
            } while (taken.has(id));

            return id;

        }


        buildCopiedTitle(baseTitle, existingTitles) {

            const baseline = String(baseTitle || "Untitled Project").trim() || "Untitled Project";
            const existing = new Set((Array.isArray(existingTitles) ? existingTitles : []).map(title => String(title || "").trim().toLowerCase()));

            if (!existing.has(baseline.toLowerCase())) {
                return baseline;
            }

            let index = 1;
            let candidate = `${baseline} (Imported Copy)`;

            while (existing.has(candidate.toLowerCase())) {
                index += 1;
                candidate = `${baseline} (Imported Copy ${index})`;
            }

            return candidate;

        }


        sanitizeFilenamePart(value) {

            const normalized = String(value || "")
                .normalize("NFKD")
                .replace(/[^a-zA-Z0-9\s_-]/g, "")
                .trim()
                .replace(/\s+/g, "-")
                .replace(/-+/g, "-")
                .replace(/^[-_.]+|[-_.]+$/g, "");

            return normalized || "Project";

        }


        getDateStamp() {
            const now = new Date();
            const year = now.getFullYear();
            const month = String(now.getMonth() + 1).padStart(2, "0");
            const day = String(now.getDate()).padStart(2, "0");
            return `${year}-${month}-${day}`;
        }


        getAuthorOSVersion() {
            return String(this.core?.getVersion?.() || this.core?.state?.get("app.version") || "0.1.0");
        }


        async downloadJson(payload, fileName) {
            return this.downloadText(JSON.stringify(payload, null, 2), fileName, "application/json;charset=utf-8");
        }


        async downloadText(text, fileName, mimeType) {

            if (window.AuthorOSDesktop?.isTauri?.()) {
                return window.AuthorOSDesktop.saveTextFile({
                    fileName,
                    text,
                    mimeType
                });
            }

            try {

                if (typeof Blob !== "function" || typeof URL === "undefined" || typeof URL.createObjectURL !== "function") {
                    return {
                        ok: false,
                        error: "Export is unavailable in this runtime."
                    };
                }

                const content = String(text || "");
                const blob = new Blob([content], { type: mimeType || "text/plain;charset=utf-8" });
                const url = URL.createObjectURL(blob);

                const link = document.createElement("a");
                link.href = url;
                link.download = String(fileName || `Author-Studio-Export-${this.getDateStamp()}.txt`);
                link.rel = "noopener";
                link.click();

                URL.revokeObjectURL(url);

                return {
                    ok: true,
                    bytes: blob.size
                };

            } catch (error) {

                console.error("AuthorOS export download failed:", error);

                return {
                    ok: false,
                    error: "Download failed in current runtime."
                };

            }

        }


        saveRecentExportInfo(info) {

            if (!this.core?.storage || typeof this.core.storage.set !== "function") {
                return;
            }

            const record = {
                type: String(info?.type || "export"),
                fileName: String(info?.fileName || ""),
                exportedAt: String(info?.exportedAt || new Date().toISOString()),
                projectCount: this.toSafeNumber(info?.projectCount, 0),
                ideaCount: this.toSafeNumber(info?.ideaCount, 0),
                bytes: this.toSafeNumber(info?.bytes, 0)
            };

            this.core.storage.set("backupExportRecent", record);

        }


        getRecentExportInfo() {
            const record = this.core?.storage?.get?.("backupExportRecent", null);
            return record && typeof record === "object" ? record : null;
        }


        cloneData(value) {
            try {
                return JSON.parse(JSON.stringify(value));
            } catch (error) {
                return null;
            }
        }


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }


        escapeText(value) {
            return String(value || "").replace(/[#*_`~>]/g, match => `\\${match}`);
        }

    }


    window.AuthorOSBackupExportService = AuthorOSBackupExportService;

})();
