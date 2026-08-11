/*
=========================================================
AUTHOROS
TUTORIAL SERVICE
Milestone 15
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSTutorialService {

        constructor(core) {
            this.core = core;
            this.active = false;
            this.overlay = null;
            this.focusRing = null;
            this.card = null;
            this.highlightedElement = null;
            this.renderTimer = null;

            this.boundProjectCreated = this.handleProjectCreated.bind(this);
            this.boundChapterCreated = this.handleChapterCreated.bind(this);
            this.boundNavigationChanged = this.handleNavigationChanged.bind(this);
            this.boundViewportChanged = this.handleViewportChanged.bind(this);
        }


        initialize() {
            this.core.events.on("project:created", this.boundProjectCreated);
            this.core.events.on("chapter:created", this.boundChapterCreated);
            this.core.events.on("navigation:changed", this.boundNavigationChanged);

            window.addEventListener("resize", this.boundViewportChanged);
            window.addEventListener("scroll", this.boundViewportChanged, true);

            this.ensureOverlay();
        }


        startIfNeeded() {

            const tutorial = this.getTutorialState();

            if (!tutorial.enabled || tutorial.completed || tutorial.dismissed) {
                return false;
            }

            this.start();
            return true;

        }


        start(force = false) {

            const tutorial = this.getTutorialState();

            if (!force && (!tutorial.enabled || tutorial.completed || tutorial.dismissed)) {
                return;
            }

            this.active = true;
            this.updateTutorialState({
                enabled: true,
                completed: false,
                dismissed: false,
                lastPromptedAt: new Date().toISOString()
            });

            const step = String(this.getTutorialState().currentStep || "welcome").trim() || "welcome";
            this.showStep(step);

        }


        restart() {
            this.active = true;
            this.updateTutorialState({
                enabled: true,
                completed: false,
                dismissed: false,
                currentStep: "welcome",
                completedAt: "",
                lastPromptedAt: new Date().toISOString()
            });
            this.showStep("welcome");
        }


        resume() {

            const tutorial = this.getTutorialState();

            if (tutorial.completed) {
                this.restart();
                return;
            }

            this.start(true);

        }


        dismiss() {
            this.active = false;
            this.hideOverlay();
            this.updateTutorialState({
                dismissed: true,
                currentStep: "welcome"
            });
        }


        complete() {
            this.active = false;
            this.hideOverlay();
            this.updateTutorialState({
                completed: true,
                dismissed: false,
                currentStep: "complete",
                completedAt: new Date().toISOString()
            });
        }


        showStep(stepId) {

            const step = this.getStepDefinition(stepId);

            if (!step) {
                this.complete();
                return;
            }

            this.active = true;
            this.updateTutorialState({ currentStep: step.id });

            if (step.route && this.core.state.get("app.currentView") !== step.route) {
                this.core.navigation.navigate(step.route);
            }

            this.scheduleOverlayRender(step.id);

        }


        handleProjectCreated() {

            if (!this.active) {
                return;
            }

            if (this.getTutorialState().currentStep !== "create-project") {
                return;
            }

            this.showStep("project-created");

        }


        handleChapterCreated() {

            if (!this.active) {
                return;
            }

            if (this.getTutorialState().currentStep !== "create-chapter") {
                return;
            }

            this.showStep("writing-editor");

        }


        handleNavigationChanged() {

            if (!this.active) {
                return;
            }

            const currentStep = this.getTutorialState().currentStep;

            if (!currentStep || currentStep === "complete") {
                return;
            }

            this.scheduleOverlayRender(currentStep);

        }


        handleViewportChanged() {

            if (!this.active) {
                return;
            }

            const currentStep = this.getTutorialState().currentStep;

            if (!currentStep || currentStep === "complete") {
                return;
            }

            this.scheduleOverlayRender(currentStep);

        }


        getStepDefinition(stepId) {

            const steps = {
                welcome: {
                    id: "welcome",
                    route: "dashboard",
                    selector: "#app-toolbar",
                    title: "Welcome to Author Studio",
                    content: `
                        <p>This short tutorial walks through the core writing flow: projects, chapters, and the editor.</p>
                        <p>You can skip now and restart it later from Settings.</p>
                    `,
                    confirmText: "Start Tutorial",
                    nextStep: "dashboard-intro"
                },
                "dashboard-intro": {
                    id: "dashboard-intro",
                    route: "dashboard",
                    selector: '[data-route="projects"]',
                    title: "Open Story Library",
                    content: `
                        <p>Story Library is where your projects live.</p>
                        <p>The highlighted navigation item opens it.</p>
                    `,
                    confirmText: "Open Story Library",
                    nextStep: "projects-intro"
                },
                "projects-intro": {
                    id: "projects-intro",
                    route: "projects",
                    selector: '[data-action="new-project"]',
                    title: "Create a Project",
                    content: `
                        <p>Projects store your manuscript, characters, worldbuilding, plot planning, and notes together.</p>
                        <p>We will use the highlighted button next.</p>
                    `,
                    confirmText: "Highlight New Project",
                    nextStep: "create-project"
                },
                "create-project": {
                    id: "create-project",
                    route: "projects",
                    selector: '[data-action="new-project"]',
                    title: "Create Your First Project",
                    content: `
                        <p>Use the highlighted <strong>New Project</strong> button.</p>
                        <p>The tutorial will continue automatically after the project is created.</p>
                    `,
                    confirmText: "I’ll Create It Now",
                    waitForAction: true,
                    onConfirm: () => {
                        this.core.notify("Create your first project using the highlighted button.", "success");
                    }
                },
                "project-created": {
                    id: "project-created",
                    route: "manuscript",
                    selector: '[data-action="create-chapter"]',
                    title: "Project Ready",
                    content: `
                        <p>Your project is ready.</p>
                        <p>Next, use the highlighted button to create your first chapter.</p>
                    `,
                    confirmText: "Show Chapter Button",
                    nextStep: "create-chapter"
                },
                "create-chapter": {
                    id: "create-chapter",
                    route: "manuscript",
                    selector: '[data-action="create-chapter"]',
                    title: "Create Your First Chapter",
                    content: `
                        <p>Use the highlighted <strong>Chapter</strong> button to add your first chapter.</p>
                        <p>The tutorial will continue automatically once the chapter exists.</p>
                    `,
                    confirmText: "I’ll Create It Now",
                    waitForAction: true,
                    onConfirm: () => {
                        this.core.notify("Create the chapter using the highlighted button.", "success");
                    }
                },
                "writing-editor": {
                    id: "writing-editor",
                    route: "manuscript",
                    selector: "#manuscript-editor",
                    title: "Start Writing",
                    content: `
                        <p>This is your writing area.</p>
                        <p>Draft here, use the chapter list to switch sections, and the controls panel to manage writing settings and goals.</p>
                    `,
                    confirmText: "Finish Tutorial",
                    nextStep: "complete"
                },
                complete: {
                    id: "complete",
                    route: "manuscript",
                    selector: '[data-route="characters"]',
                    title: "Tutorial Complete",
                    content: `
                        <p>You are ready to use Author Studio.</p>
                        <p>Next good places to explore are Characters, World, Plot, Notes, and Backup & Export.</p>
                    `,
                    confirmText: "Done",
                    cancelText: "Close",
                    completeOnConfirm: true,
                    onCancel: () => {
                        this.complete();
                    }
                }
            };

            return steps[String(stepId || "").trim()] || null;

        }


        getStepSummaries() {

            const ids = [
                "welcome",
                "dashboard-intro",
                "projects-intro",
                "create-project",
                "project-created",
                "create-chapter",
                "writing-editor",
                "complete"
            ];

            return ids.map(id => {
                const step = this.getStepDefinition(id);
                return {
                    id,
                    title: step?.title || id
                };
            });

        }


        openStepList() {

            const tutorial = this.getTutorialState();
            const steps = this.getStepSummaries();
            const currentIndex = steps.findIndex(step => step.id === tutorial.currentStep);

            this.core.modal.open({
                title: "Tutorial Steps",
                confirmText: tutorial.completed ? "Restart Tutorial" : "Resume Tutorial",
                cancelText: "Close",
                content: `
                    <ol class="tutorial-steps-list">
                        ${steps.map((step, index) => {
                            const status = tutorial.completed
                                ? "Completed"
                                : index < currentIndex
                                    ? "Done"
                                    : index === currentIndex
                                        ? "Current"
                                        : "Upcoming";

                            return `
                                <li class="tutorial-steps-item">
                                    <strong>${this.escapeHTML(step.title)}</strong>
                                    <span>${this.escapeHTML(status)}</span>
                                </li>
                            `;
                        }).join("")}
                    </ol>
                `,
                onConfirm: () => {
                    if (tutorial.completed) {
                        this.restart();
                        return;
                    }

                    this.resume();
                }
            });

        }


        getTutorialState() {
            const settings = this.core.state.get("settings") || this.core.settingsService.loadSettings();
            const tutorial = settings?.tutorial && typeof settings.tutorial === "object"
                ? settings.tutorial
                : {};

            return {
                enabled: tutorial.enabled !== false,
                completed: Boolean(tutorial.completed),
                dismissed: Boolean(tutorial.dismissed),
                currentStep: String(tutorial.currentStep || "welcome").trim() || "welcome",
                completedAt: String(tutorial.completedAt || ""),
                lastPromptedAt: String(tutorial.lastPromptedAt || "")
            };
        }


        updateTutorialState(patch = {}) {

            const current = this.core.state.get("settings") || this.core.settingsService.loadSettings();
            const next = this.cloneData(current) || this.core.settingsService.getDefaultSettings();

            next.tutorial = {
                ...(next.tutorial && typeof next.tutorial === "object" ? next.tutorial : {}),
                ...patch
            };

            const result = this.core.settingsService.saveSettings(next);

            return result?.ok
                ? result.settings
                : null;

        }


        ensureOverlay() {

            if (this.overlay) {
                return;
            }

            const overlay = document.createElement("div");
            overlay.className = "tutorial-overlay";
            overlay.innerHTML = `
                <div class="tutorial-overlay-backdrop"></div>
                <div class="tutorial-focus-ring"></div>
                <section class="tutorial-card" aria-live="polite"></section>
            `;

            document.body.appendChild(overlay);

            this.overlay = overlay;
            this.focusRing = overlay.querySelector(".tutorial-focus-ring");
            this.card = overlay.querySelector(".tutorial-card");

        }


        scheduleOverlayRender(stepId) {

            window.clearTimeout(this.renderTimer);

            this.renderTimer = window.setTimeout(() => {
                this.renderOverlayStep(stepId, 0);
            }, 30);

        }


        renderOverlayStep(stepId, attempt) {

            const step = this.getStepDefinition(stepId);

            if (!this.active || !step || !this.overlay || !this.card || !this.focusRing) {
                return;
            }

            let target = null;

            if (step.selector) {
                target = document.querySelector(step.selector);
            }

            if (step.selector && !target && attempt < 12) {
                this.renderTimer = window.setTimeout(() => {
                    this.renderOverlayStep(stepId, attempt + 1);
                }, 80);
                return;
            }

            this.overlay.classList.add("active");
            this.updateHighlightedTarget(target);
            this.renderCard(step, target);
            this.positionOverlay(target);

            if (target && typeof target.scrollIntoView === "function") {
                target.scrollIntoView({ block: "center", inline: "nearest", behavior: "smooth" });
            }

        }


        renderCard(step, target) {

            if (!this.card) {
                return;
            }

            const stepIds = this.getStepSummaries().map(item => item.id);
            const currentIndex = Math.max(0, stepIds.indexOf(step.id));
            const total = stepIds.length;
            const waitText = step.waitForAction
                ? '<p class="tutorial-card-note">This step advances automatically after you complete the highlighted action.</p>'
                : "";
            const targetText = target
                ? '<p class="tutorial-card-target">Highlighted element is live and clickable.</p>'
                : '<p class="tutorial-card-target">The tutorial is waiting for the related screen to finish rendering.</p>';

            this.card.innerHTML = `
                <p class="tutorial-card-step">Step ${currentIndex + 1} of ${total}</p>
                <h3>${this.escapeHTML(step.title)}</h3>
                <div class="tutorial-card-body">${step.content}</div>
                ${targetText}
                ${waitText}
                <div class="tutorial-card-actions">
                    <button type="button" class="button button-secondary" data-action="tutorial-view-steps">View Steps</button>
                    <button type="button" class="button button-secondary" data-action="tutorial-skip">Skip</button>
                    <button type="button" class="button button-primary" data-action="tutorial-next">${this.escapeHTML(step.confirmText || (step.waitForAction ? "I Found It" : "Next"))}</button>
                </div>
            `;

            this.card.querySelector('[data-action="tutorial-skip"]')?.addEventListener("click", () => {
                if (typeof step.onCancel === "function") {
                    step.onCancel.call(this);
                    return;
                }

                this.dismiss();
                this.core.notify("Tutorial skipped. You can restart it from Settings.", "success");
            });

            this.card.querySelector('[data-action="tutorial-view-steps"]')?.addEventListener("click", () => {
                this.openStepList();
            });

            this.card.querySelector('[data-action="tutorial-next"]')?.addEventListener("click", () => {
                if (typeof step.onConfirm === "function") {
                    step.onConfirm.call(this);
                }

                if (step.completeOnConfirm) {
                    this.complete();
                    return;
                }

                if (step.waitForAction) {
                    return;
                }

                if (step.nextStep) {
                    this.showStep(step.nextStep);
                }
            });

        }


        positionOverlay(target) {

            if (!this.focusRing || !this.card) {
                return;
            }

            if (!target) {
                this.focusRing.classList.remove("visible");
                this.card.style.width = "min(340px, calc(100vw - 24px))";
                this.card.style.top = "50%";
                this.card.style.left = "50%";
                this.card.style.transform = "translate(-50%, -50%)";
                return;
            }

            const rect = target.getBoundingClientRect();
            const padding = 8;
            const top = Math.max(8, rect.top - padding);
            const left = Math.max(8, rect.left - padding);
            const width = Math.max(44, rect.width + (padding * 2));
            const height = Math.max(44, rect.height + (padding * 2));

            this.focusRing.classList.add("visible");
            this.focusRing.style.top = `${top}px`;
            this.focusRing.style.left = `${left}px`;
            this.focusRing.style.width = `${width}px`;
            this.focusRing.style.height = `${height}px`;

            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;
            const cardWidth = Math.min(340, Math.max(280, viewportWidth - 24));
            const cardHeightEstimate = 230;
            const belowTop = rect.bottom + 16;
            const aboveTop = rect.top - cardHeightEstimate - 16;
            const cardTop = belowTop + cardHeightEstimate < viewportHeight
                ? belowTop
                : Math.max(12, aboveTop);
            const preferredLeft = rect.left;
            const cardLeft = Math.min(
                Math.max(12, preferredLeft),
                Math.max(12, viewportWidth - cardWidth - 12)
            );

            this.card.style.width = `${cardWidth}px`;
            this.card.style.top = `${cardTop}px`;
            this.card.style.left = `${cardLeft}px`;
            this.card.style.transform = "none";

        }


        updateHighlightedTarget(target) {

            if (this.highlightedElement) {
                this.highlightedElement.classList.remove("tutorial-target-active");
            }

            this.highlightedElement = target instanceof HTMLElement
                ? target
                : null;

            if (this.highlightedElement) {
                this.highlightedElement.classList.add("tutorial-target-active");
            }

        }


        hideOverlay() {

            window.clearTimeout(this.renderTimer);

            if (this.overlay) {
                this.overlay.classList.remove("active");
            }

            if (this.focusRing) {
                this.focusRing.classList.remove("visible");
            }

            this.updateHighlightedTarget(null);

        }


        cloneData(value) {
            try {
                return JSON.parse(JSON.stringify(value));
            } catch (error) {
                return null;
            }
        }


        escapeHTML(value) {
            return String(value || "")
                .replaceAll("&", "&amp;")
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;")
                .replaceAll('"', "&quot;")
                .replaceAll("'", "&#039;");
        }

    }


    window.AuthorOSTutorialService = AuthorOSTutorialService;

})();
