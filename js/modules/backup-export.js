/*
=========================================================
AUTHOROS
BACKUP & EXPORT STUDIO
Milestone 13
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSBackupExport = {

        name: "backup-export",

        core: null,

        container: null,

        uiState: {
            selectedProjectId: "",
            manuscriptFormat: "md",
            pdfExportOptions: {
                pageSize: "A4",
                margin: "normal",
                includeChapterTitles: true
            },
            manuscriptImportPreview: null,
            parsingManuscriptImport: false,
            importStrategy: "copy",
            importPreview: null,
            parsingImport: false,
            applyingImport: false,
            replaceConfirmed: false
        },

        initialize(core) {
            this.core = core;
        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;

            this.ensureDefaults();

            const projects = this.getProjects();
            const selectedProject = this.getSelectedProject();
            const recent = this.getService().getRecentExportInfo();

            container.innerHTML = `
                <section class="backup-export-view library-view">
                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">BACKUP & EXPORT STUDIO</p>
                            <h1>Protect and Export Your Writing</h1>
                            <p class="library-description">
                                Create validated backups, export manuscript formats, and safely import or restore Author Studio data.
                            </p>
                        </div>
                    </header>

                    <div class="library-controls backup-export-controls">
                        <div class="library-filter-group">
                            <label for="backup-export-project">Project</label>
                            <select id="backup-export-project" class="library-filter-select" ${projects.length ? "" : "disabled"}>
                                ${projects.length
                                    ? projects.map(project => `
                                        <option value="${this.escapeHTML(project.id)}" ${selectedProject?.id === project.id ? "selected" : ""}>
                                            ${this.escapeHTML(this.getProjectTitle(project))}
                                        </option>
                                    `).join("")
                                    : "<option value=''>No projects available</option>"
                                }
                            </select>
                        </div>

                        <div class="library-filter-group">
                            <label for="backup-export-strategy">Import strategy</label>
                            <select id="backup-export-strategy" class="library-filter-select">
                                <option value="copy" ${this.uiState.importStrategy === "copy" ? "selected" : ""}>Import as new copy (safe)</option>
                                <option value="skip" ${this.uiState.importStrategy === "skip" ? "selected" : ""}>Skip conflicting records</option>
                                <option value="replace" ${this.uiState.importStrategy === "replace" ? "selected" : ""}>Replace conflicting project (advanced)</option>
                            </select>
                        </div>

                        <div class="backup-export-pill" aria-label="Backup format version">
                            Format v${this.escapeHTML(this.getService().formatVersion)}
                        </div>
                    </div>

                    <div class="library-results-bar backup-export-status-row">
                        <span class="library-count">${projects.length} project${projects.length === 1 ? "" : "s"} available</span>
                        ${recent
                            ? `<span class="library-filter-state">Last export: ${this.escapeHTML(recent.fileName)} (${this.formatDate(recent.exportedAt)})</span>`
                            : ""
                        }
                    </div>

                    <div class="backup-export-grid">
                        ${this.renderBackupPanel(selectedProject)}
                        ${this.renderManuscriptPanel(selectedProject)}
                        ${this.renderImportPanel()}
                        ${this.renderPreviewPanel()}
                    </div>
                </section>
            `;

            this.bindEvents(container);

        },


        renderBackupPanel(selectedProject) {

            return `
                <article class="backup-export-panel">
                    <header class="backup-export-panel-header">
                        <h2>Backup and Structured Export</h2>
                    </header>

                    <p class="backup-export-panel-copy">
                        Every backup is validated before download. Backups include version metadata and canonical project relationships.
                    </p>

                    <div class="backup-export-actions">
                        <button type="button" class="button button-primary" data-action="export-full-backup">
                            Export Full Backup
                        </button>

                        <button type="button" class="button button-secondary" data-action="export-project-backup" ${selectedProject ? "" : "disabled"}>
                            Export Project Backup
                        </button>

                        <button type="button" class="button button-secondary" data-action="export-structured-project" ${selectedProject ? "" : "disabled"}>
                            Export Structured JSON
                        </button>
                    </div>

                    <ul class="backup-export-notes">
                        <li>No statistics caches, search indexes, or transient UI state are exported.</li>
                        <li>Backup files preserve IDs and relationships for project-scoped records.</li>
                        <li>Live data remains unchanged when creating exports.</li>
                    </ul>
                </article>
            `;

        },


        renderManuscriptPanel(selectedProject) {

            return `
                <article class="backup-export-panel">
                    <header class="backup-export-panel-header">
                        <h2>Manuscript Export</h2>
                    </header>

                    <p class="backup-export-panel-copy">
                        Export chapter content in order without internal app metadata.
                    </p>

                    <div class="backup-export-actions backup-export-actions-inline">
                        <button type="button" class="button button-secondary" data-action="export-manuscript" data-format="txt" ${selectedProject ? "" : "disabled"}>
                            Export TXT
                        </button>

                        <button type="button" class="button button-secondary" data-action="export-manuscript" data-format="md" ${selectedProject ? "" : "disabled"}>
                            Export Markdown
                        </button>

                        <button type="button" class="button button-secondary" data-action="export-manuscript" data-format="html" ${selectedProject ? "" : "disabled"}>
                            Export HTML
                        </button>

                        <button type="button" class="button button-secondary" data-action="export-manuscript" data-format="doc" ${selectedProject ? "" : "disabled"}>
                            Export Word (.doc)
                        </button>

                        <button type="button" class="button button-secondary" data-action="export-manuscript" data-format="pdf" ${selectedProject ? "" : "disabled"}>
                            Export PDF
                        </button>
                    </div>

                    <div class="backup-export-actions backup-export-actions-inline">
                        <button type="button" class="button button-primary" data-action="select-manuscript-import-file" ${selectedProject && !this.uiState.parsingManuscriptImport ? "" : "disabled"}>
                            Import Manuscript File
                        </button>

                        <button type="button" class="button button-secondary" data-action="clear-manuscript-import-preview" ${this.uiState.manuscriptImportPreview ? "" : "disabled"}>
                            Clear Import Preview
                        </button>
                    </div>

                    <input
                        id="manuscript-import-input"
                        class="visually-hidden"
                        type="file"
                        accept=".txt,.md,.markdown,.html,.htm,.doc,text/plain,text/markdown,text/html,application/msword"
                    >

                    ${this.renderManuscriptImportPreview(selectedProject)}

                    <ul class="backup-export-notes">
                        <li>Supported import formats: TXT, Markdown, HTML, and Author Studio Word (.doc) exports.</li>
                        <li>Imported documents are added as new chapters to the selected project.</li>
                        <li>Scenes, characters, and world entries are not auto-created from manuscript imports in this pass.</li>
                    </ul>
                </article>
            `;

        },


        renderManuscriptImportPreview(selectedProject) {

            if (this.uiState.parsingManuscriptImport) {
                return `
                    <section class="backup-export-preview-block">
                        <h3>Document Import Preview</h3>
                        <p class="backup-export-panel-copy">Reading and splitting manuscript document...</p>
                    </section>
                `;
            }

            const preview = this.uiState.manuscriptImportPreview;

            if (!preview) {
                return `
                    <section class="backup-export-preview-block">
                        <h3>Document Import Preview</h3>
                        <p class="backup-export-panel-copy">Choose a manuscript document to preview chapter splits before import.</p>
                    </section>
                `;
            }

            return `
                <section class="backup-export-preview-block">
                    <h3>Document Import Preview</h3>
                    <dl class="backup-export-kv-grid">
                        <div><dt>File</dt><dd>${this.escapeHTML(preview.fileName || "Unknown")}</dd></div>
                        <div><dt>Format</dt><dd>${this.escapeHTML(String(preview.format || "").toUpperCase())}</dd></div>
                        <div><dt>Size</dt><dd>${this.formatBytes(preview.fileSize || 0)}</dd></div>
                        <div><dt>Detected Chapters</dt><dd>${this.number(preview.chapterCount || 0)}</dd></div>
                        <div><dt>Total Words</dt><dd>${this.number(preview.totalWords || 0)}</dd></div>
                        <div><dt>Target Project</dt><dd>${this.escapeHTML(this.getProjectTitle(selectedProject))}</dd></div>
                    </dl>

                    ${preview.warnings?.length
                        ? `
                            <section class="backup-export-preview-block backup-export-warning-block">
                                <h3>Import Notes</h3>
                                <ul class="backup-export-list">
                                    ${preview.warnings.map(warning => `<li>${this.escapeHTML(warning)}</li>`).join("")}
                                </ul>
                            </section>
                        `
                        : ""
                    }

                    <section class="backup-export-preview-block">
                        <h3>Chapters to Import</h3>
                        <ul class="backup-export-list">
                            ${preview.chapters.slice(0, 8).map((chapter, index) => `
                                <li>
                                    <strong>${this.escapeHTML(chapter.title || `Chapter ${index + 1}`)}</strong>
                                    <div>${this.number(chapter.wordCount || 0)} words</div>
                                </li>
                            `).join("")}
                        </ul>
                        ${preview.chapters.length > 8 ? `<p class="backup-export-panel-copy">Showing first 8 of ${this.number(preview.chapters.length)} chapters.</p>` : ""}
                    </section>

                    <div class="backup-export-actions">
                        <button type="button" class="button button-primary" data-action="confirm-manuscript-import" ${selectedProject ? "" : "disabled"}>
                            Import as New Chapters
                        </button>
                    </div>
                </section>
            `;

        },


        renderImportPanel() {

            return `
                <article class="backup-export-panel backup-export-panel-wide">
                    <header class="backup-export-panel-header">
                        <h2>Import and Restore</h2>
                    </header>

                    <p class="backup-export-panel-copy">
                        Imported files are parsed as untrusted JSON, validated against backup schema, and never applied automatically.
                    </p>

                    <div class="backup-export-actions">
                        <button type="button" class="button button-primary" data-action="select-import-file" ${this.uiState.parsingImport || this.uiState.applyingImport ? "disabled" : ""}>
                            Select Backup File
                        </button>

                        <button type="button" class="button button-secondary" data-action="clear-import-preview" ${this.uiState.importPreview ? "" : "disabled"}>
                            Clear Preview
                        </button>
                    </div>

                    <input
                        id="backup-import-input"
                        class="visually-hidden"
                        type="file"
                        accept="application/json,.json"
                    >

                    <label class="backup-export-checkbox ${this.uiState.importStrategy === "replace" ? "" : "hidden"}">
                        <input id="backup-replace-confirm" type="checkbox" ${this.uiState.replaceConfirmed ? "checked" : ""}>
                        <span>I understand replace mode can overwrite an existing conflicting project.</span>
                    </label>
                </article>
            `;

        },


        renderPreviewPanel() {

            if (this.uiState.parsingImport) {
                return `
                    <article class="backup-export-panel backup-export-panel-wide">
                        <header class="backup-export-panel-header">
                            <h2>Import Preview</h2>
                        </header>
                        <p class="backup-export-panel-copy">Parsing and validating backup file...</p>
                    </article>
                `;
            }

            if (!this.uiState.importPreview) {
                return `
                    <article class="backup-export-panel backup-export-panel-wide">
                        <header class="backup-export-panel-header">
                            <h2>Import Preview</h2>
                        </header>
                        <p class="backup-export-panel-copy">Select a backup file to see metadata, counts, conflicts, and warnings before import.</p>
                    </article>
                `;
            }

            const preview = this.uiState.importPreview;
            const conflicts = preview.conflicts || { hasConflicts: false, projectConflicts: [], ideaConflicts: [] };

            return `
                <article class="backup-export-panel backup-export-panel-wide">
                    <header class="backup-export-panel-header">
                        <h2>Import Preview</h2>
                    </header>

                    <dl class="backup-export-kv-grid">
                        <div><dt>File</dt><dd>${this.escapeHTML(preview.fileName || "Unknown")}</dd></div>
                        <div><dt>Size</dt><dd>${this.formatBytes(preview.fileSize || 0)}</dd></div>
                        <div><dt>Scope</dt><dd>${this.escapeHTML(preview.backupType || "Unknown")}</dd></div>
                        <div><dt>Format Version</dt><dd>${this.escapeHTML(preview.formatVersion || "Unknown")}</dd></div>
                        <div><dt>Author Studio Version</dt><dd>${this.escapeHTML(preview.authorOSVersion || "Unknown")}</dd></div>
                        <div><dt>Exported</dt><dd>${this.formatDate(preview.exportedAt)}</dd></div>
                        <div><dt>Projects</dt><dd>${this.number(preview.counts?.projects || 0)}</dd></div>
                        <div><dt>Ideas</dt><dd>${this.number(preview.counts?.ideas || 0)}</dd></div>
                        <div><dt>Chapters</dt><dd>${this.number(preview.counts?.chapters || 0)}</dd></div>
                        <div><dt>Scenes</dt><dd>${this.number(preview.counts?.scenes || 0)}</dd></div>
                        <div><dt>Characters</dt><dd>${this.number(preview.counts?.characters || 0)}</dd></div>
                        <div><dt>World Entries</dt><dd>${this.number(preview.counts?.worldEntries || 0)}</dd></div>
                        <div><dt>Timeline Events</dt><dd>${this.number(preview.counts?.timelineEvents || 0)}</dd></div>
                        <div><dt>Notes Records</dt><dd>${this.number(preview.counts?.notesRecords || 0)}</dd></div>
                        <div><dt>Notes Sources</dt><dd>${this.number(preview.counts?.notesSources || 0)}</dd></div>
                        <div><dt>Conflicts</dt><dd>${conflicts.hasConflicts ? "Detected" : "None"}</dd></div>
                    </dl>

                    ${preview.projectNames?.length
                        ? `
                            <section class="backup-export-preview-block">
                                <h3>Projects in file</h3>
                                <ul class="backup-export-list">
                                    ${preview.projectNames.map(name => `<li>${this.escapeHTML(name)}</li>`).join("")}
                                </ul>
                            </section>
                        `
                        : ""
                    }

                    ${conflicts.projectConflicts.length || conflicts.ideaConflicts.length
                        ? `
                            <section class="backup-export-preview-block backup-export-warning-block">
                                <h3>Detected conflicts</h3>
                                <ul class="backup-export-list">
                                    ${conflicts.projectConflicts.map(conflict => `
                                        <li>
                                            Project ${this.escapeHTML(conflict.projectName)}
                                            ${conflict.idConflict ? "(ID conflict)" : ""}
                                            ${conflict.nameConflict ? "(Name conflict)" : ""}
                                        </li>
                                    `).join("")}
                                    ${conflicts.ideaConflicts.map(conflict => `
                                        <li>
                                            Idea ${this.escapeHTML(conflict.title)} (ID conflict)
                                        </li>
                                    `).join("")}
                                </ul>
                            </section>
                        `
                        : ""
                    }

                    <div class="backup-export-actions">
                        <button
                            type="button"
                            class="button button-primary"
                            data-action="confirm-import-commit"
                            ${this.uiState.applyingImport ? "disabled" : ""}
                        >
                            ${this.uiState.applyingImport ? "Importing..." : "Confirm Import"}
                        </button>
                    </div>
                </article>
            `;

        },


        bindEvents(container) {

            container.querySelector("#backup-export-project")?.addEventListener("change", event => {
                this.uiState.selectedProjectId = String(event.currentTarget.value || "");
                this.render(this.container);
            });

            container.querySelector("#backup-export-strategy")?.addEventListener("change", event => {
                this.uiState.importStrategy = this.getService().normalizeImportStrategy(event.currentTarget.value);
                this.uiState.replaceConfirmed = false;
                this.render(this.container);
            });

            container.querySelector("#backup-replace-confirm")?.addEventListener("change", event => {
                this.uiState.replaceConfirmed = Boolean(event.currentTarget.checked);
            });

            container.querySelector('[data-action="export-full-backup"]')?.addEventListener("click", async event => {
                event.preventDefault();
                await this.handleFullBackupExport();
            });

            container.querySelector('[data-action="export-project-backup"]')?.addEventListener("click", async event => {
                event.preventDefault();
                await this.handleProjectBackupExport();
            });

            container.querySelector('[data-action="export-structured-project"]')?.addEventListener("click", async event => {
                event.preventDefault();
                await this.handleStructuredExport();
            });

            container.querySelectorAll('[data-action="export-manuscript"]').forEach(button => {
                button.addEventListener("click", async event => {
                    event.preventDefault();
                    await this.handleManuscriptExport(button.dataset.format);
                });
            });

            container.querySelector('[data-action="select-manuscript-import-file"]')?.addEventListener("click", async event => {
                event.preventDefault();

                if (window.AuthorOSDesktop?.isTauri?.()) {
                    await this.handleDesktopManuscriptImportSelection();
                    return;
                }

                container.querySelector("#manuscript-import-input")?.click();
            });

            container.querySelector('[data-action="clear-manuscript-import-preview"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.manuscriptImportPreview = null;
                this.render(this.container);
            });

            container.querySelector("#manuscript-import-input")?.addEventListener("change", async event => {
                const input = event.currentTarget;
                const file = input?.files?.[0] || null;

                await this.handleManuscriptImportSelection(file);

                if (input) {
                    input.value = "";
                }
            });

            container.querySelector('[data-action="confirm-manuscript-import"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.handleConfirmManuscriptImport();
            });

            container.querySelector('[data-action="select-import-file"]')?.addEventListener("click", async event => {
                event.preventDefault();

                if (window.AuthorOSDesktop?.isTauri?.()) {
                    await this.handleDesktopBackupImportSelection();
                    return;
                }

                container.querySelector("#backup-import-input")?.click();
            });

            container.querySelector('[data-action="clear-import-preview"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.importPreview = null;
                this.uiState.replaceConfirmed = false;
                this.render(this.container);
            });

            container.querySelector("#backup-import-input")?.addEventListener("change", async event => {
                const input = event.currentTarget;
                const file = input?.files?.[0] || null;

                await this.handleImportFileSelection(file);

                if (input) {
                    input.value = "";
                }
            });

            container.querySelector('[data-action="confirm-import-commit"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.handleConfirmImport();
            });

        },


        async handleFullBackupExport() {

            const result = await this.getService().exportFullBackup();

            if (!result.ok) {
                this.core.notify(result.error || "Full backup export failed.", "error");
                return;
            }

            this.core.notify(`Full backup exported: ${result.fileName}`, "success");
            this.render(this.container);

        },


        async handleProjectBackupExport() {

            const project = this.getSelectedProject();

            if (!project) {
                this.core.notify("Select a project before exporting project backup.", "error");
                return;
            }

            const result = await this.getService().exportProjectBackup(project.id);

            if (!result.ok) {
                this.core.notify(result.error || "Project backup export failed.", "error");
                return;
            }

            this.core.notify(`Project backup exported: ${result.fileName}`, "success");
            this.render(this.container);

        },


        async handleStructuredExport() {

            const project = this.getSelectedProject();

            if (!project) {
                this.core.notify("Select a project before structured export.", "error");
                return;
            }

            const result = await this.getService().exportStructuredProject(project.id);

            if (!result.ok) {
                this.core.notify(result.error || "Structured export failed.", "error");
                return;
            }

            this.core.notify(`Structured export created: ${result.fileName}`, "success");
            this.render(this.container);

        },


        async handleManuscriptExport(format) {

            const project = this.getSelectedProject();

            if (!project) {
                this.core.notify("Select a project before manuscript export.", "error");
                return;
            }

            const normalizedFormat = String(format || "").trim().toLowerCase();

            if (normalizedFormat === "pdf") {
                this.showPdfExportOptionsModal(project.id);
                return;
            }

            const result = await this.getService().exportManuscript(project.id, format);

            if (!result.ok) {
                this.core.notify(result.error || "Manuscript export failed.", "error");
                return;
            }

            if (result.delivery === "print-dialog") {
                this.core.notify(`Print dialog opened for PDF export: ${result.fileName}`, "success");
            } else {
                this.core.notify(`Manuscript exported: ${result.fileName}`, "success");
            }
            this.render(this.container);

        },


        async handleManuscriptImportSelection(file) {

            if (!file) {
                return;
            }

            this.uiState.parsingManuscriptImport = true;
            this.uiState.manuscriptImportPreview = null;
            this.render(this.container);

            const parsed = await this.getService().parseManuscriptImportFile(file);

            this.uiState.parsingManuscriptImport = false;

            if (!parsed.ok) {
                this.core.notify(parsed.error || "Manuscript import preview failed.", "error");
                this.render(this.container);
                return;
            }

            this.uiState.manuscriptImportPreview = parsed.preview;
            this.core.notify("Document import preview is ready. Review chapters before importing.", "success");
            this.render(this.container);

        },


        async handleDesktopManuscriptImportSelection() {

            const selected = await window.AuthorOSDesktop.openFile({
                filters: [
                    {
                        name: "Manuscript files",
                        extensions: ["txt", "md", "markdown", "html", "htm", "doc"]
                    }
                ]
            });

            if (selected.canceled) {
                return;
            }

            if (!selected.ok) {
                this.core.notify(selected.error || "Unable to open manuscript file.", "error");
                return;
            }

            await this.handleManuscriptImportSelection(selected.file);

        },


        async handleDesktopBackupImportSelection() {

            const selected = await window.AuthorOSDesktop.openFile({
                filters: [
                    {
                        name: "Author Studio backup",
                        extensions: ["json"]
                    }
                ],
                mimeType: "application/json"
            });

            if (selected.canceled) {
                return;
            }

            if (!selected.ok) {
                this.core.notify(selected.error || "Unable to open backup file.", "error");
                return;
            }

            await this.handleImportFileSelection(selected.file);

        },


        handleConfirmManuscriptImport() {

            const project = this.getSelectedProject();

            if (!project) {
                this.core.notify("Select a project before importing a manuscript document.", "error");
                return;
            }

            if (!this.uiState.manuscriptImportPreview) {
                this.core.notify("No manuscript import preview is available.", "error");
                return;
            }

            const result = this.getService().importParsedManuscript(project.id, this.uiState.manuscriptImportPreview);

            if (!result.ok) {
                this.core.notify(result.error || "Manuscript import failed.", "error");
                return;
            }

            this.uiState.manuscriptImportPreview = null;
            this.core.notify(`Imported ${result.importedChapterCount} chapter${result.importedChapterCount === 1 ? "" : "s"} into ${result.projectName}.`, "success");
            this.render(this.container);

        },


        showPdfExportOptionsModal(projectId) {

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                const fallback = await this.getService().exportManuscript(projectId, "pdf", this.uiState.pdfExportOptions);

                if (!fallback.ok) {
                    this.core.notify(fallback.error || "PDF export failed.", "error");
                    return;
                }

                this.core.notify(`Print dialog opened for PDF export: ${fallback.fileName}`, "success");
                this.render(this.container);
                return;
            }

            const options = this.getPdfExportOptions();

            this.core.modal.open({
                title: "PDF Export Settings",
                confirmText: "Open Print Dialog",
                content: `
                    <div class="backup-export-pdf-options">
                        <label class="form-field" for="pdf-export-page-size">
                            <span>Page Size</span>
                            <select id="pdf-export-page-size">
                                <option value="A4" ${options.pageSize === "A4" ? "selected" : ""}>A4</option>
                                <option value="Letter" ${options.pageSize === "Letter" ? "selected" : ""}>Letter</option>
                            </select>
                        </label>

                        <label class="form-field" for="pdf-export-margin">
                            <span>Margins</span>
                            <select id="pdf-export-margin">
                                <option value="narrow" ${options.margin === "narrow" ? "selected" : ""}>Narrow</option>
                                <option value="normal" ${options.margin === "normal" ? "selected" : ""}>Normal</option>
                                <option value="wide" ${options.margin === "wide" ? "selected" : ""}>Wide</option>
                            </select>
                        </label>

                        <label class="backup-export-checkbox">
                            <input id="pdf-export-include-chapter-titles" type="checkbox" ${options.includeChapterTitles ? "checked" : ""}>
                            <span>Include chapter titles</span>
                        </label>
                    </div>
                `,
                onConfirm: () => {
                    const nextOptions = {
                        pageSize: String(document.getElementById("pdf-export-page-size")?.value || "A4"),
                        margin: String(document.getElementById("pdf-export-margin")?.value || "normal"),
                        includeChapterTitles: Boolean(document.getElementById("pdf-export-include-chapter-titles")?.checked)
                    };

                    this.uiState.pdfExportOptions = nextOptions;

                    const result = await this.getService().exportManuscript(projectId, "pdf", nextOptions);

                    if (!result.ok) {
                        this.core.notify(result.error || "PDF export failed.", "error");
                        return;
                    }

                    this.core.notify(`Print dialog opened for PDF export: ${result.fileName}`, "success");
                    this.render(this.container);
                }
            });

        },


        getPdfExportOptions() {

            const source = this.uiState.pdfExportOptions && typeof this.uiState.pdfExportOptions === "object"
                ? this.uiState.pdfExportOptions
                : {};

            const pageSize = String(source.pageSize || "A4").trim();
            const margin = String(source.margin || "normal").trim().toLowerCase();

            return {
                pageSize: ["A4", "Letter"].includes(pageSize) ? pageSize : "A4",
                margin: ["narrow", "normal", "wide"].includes(margin) ? margin : "normal",
                includeChapterTitles: source.includeChapterTitles !== false
            };

        },


        async handleImportFileSelection(file) {

            if (!file) {
                return;
            }

            this.uiState.parsingImport = true;
            this.uiState.importPreview = null;
            this.uiState.replaceConfirmed = false;
            this.render(this.container);

            const parsed = await this.getService().parseBackupFile(file);

            this.uiState.parsingImport = false;

            if (!parsed.ok) {
                this.uiState.importPreview = null;
                this.core.notify(parsed.error || "Import file validation failed.", "error");
                this.render(this.container);
                return;
            }

            this.uiState.importPreview = {
                ...parsed.preview,
                payload: parsed.payload
            };

            this.core.notify("Backup file validated. Review preview before import.", "success");
            this.render(this.container);

        },


        handleConfirmImport() {

            const preview = this.uiState.importPreview;

            if (!preview || !preview.payload) {
                this.core.notify("No validated import preview is available.", "error");
                return;
            }

            const strategy = this.getService().normalizeImportStrategy(this.uiState.importStrategy);

            if (strategy === "replace" && !this.uiState.replaceConfirmed) {
                this.core.notify("Confirm replace mode checkbox before continuing.", "error");
                return;
            }

            const stage = this.getService().stageImport(preview.payload, {
                strategy
            });

            if (!stage.ok) {
                this.core.notify(stage.error || "Import staging failed.", "error");
                return;
            }

            const apply = () => {
                this.uiState.applyingImport = true;
                this.render(this.container);

                const committed = this.getService().commitImport(stage);

                this.uiState.applyingImport = false;

                if (!committed.ok) {
                    this.core.notify(committed.error || "Import commit failed.", "error");
                    this.render(this.container);
                    return;
                }

                const importedProjectCount = stage.summary.importedProjects.length;
                const importedIdeaCount = stage.summary.importedIdeas.length;

                this.core.notify(
                    `Import complete: ${importedProjectCount} project${importedProjectCount === 1 ? "" : "s"}, ${importedIdeaCount} idea${importedIdeaCount === 1 ? "" : "s"}.`,
                    "success"
                );

                this.uiState.importPreview = null;
                this.uiState.replaceConfirmed = false;
                this.ensureDefaults();
                this.render(this.container);
            };

            if (strategy === "replace") {
                this.core.modal.open({
                    title: "Confirm Replace Import",
                    content: "<p>This import strategy can replace conflicting project records. A safety backup is attempted before replacement where available.</p><p>Continue only if you understand this may overwrite existing project data for conflicts.</p>",
                    confirmText: "Import With Replace",
                    onConfirm: () => {
                        apply();
                    }
                });
                return;
            }

            apply();

        },


        ensureDefaults() {

            const projects = this.getProjects();
            const currentProject = this.core.state.get("currentProject");

            if (!projects.length) {
                this.uiState.selectedProjectId = "";
                return;
            }

            const selectedExists = projects.some(project => project.id === this.uiState.selectedProjectId);

            if (selectedExists) {
                return;
            }

            if (currentProject?.id && projects.some(project => project.id === currentProject.id)) {
                this.uiState.selectedProjectId = currentProject.id;
                return;
            }

            this.uiState.selectedProjectId = String(projects[0].id || "");

        },


        getSelectedProject() {
            return this.getProjects().find(project => project.id === this.uiState.selectedProjectId) || null;
        },


        getProjects() {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects)
                ? projects.filter(project => String(project?.status || "") !== "Archived")
                : [];
        },


        getProjectTitle(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        },


        getService() {
            return this.core.backupExportService;
        },


        formatDate(value) {
            const date = new Date(value || "");
            if (Number.isNaN(date.getTime())) {
                return "Unavailable";
            }
            return date.toLocaleString();
        },


        formatBytes(value) {
            const bytes = Number(value || 0);

            if (!Number.isFinite(bytes) || bytes <= 0) {
                return "0 B";
            }

            if (bytes < 1024) {
                return `${bytes} B`;
            }

            if (bytes < 1024 * 1024) {
                return `${(bytes / 1024).toFixed(1)} KB`;
            }

            return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
        },


        number(value) {
            const parsed = Number(value || 0);
            return Number.isFinite(parsed) ? parsed.toLocaleString() : "0";
        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();
