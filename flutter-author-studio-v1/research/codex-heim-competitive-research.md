# Codex Heim Competitive Research

Research date: August 16, 2026  
Official site: https://codexheim.com/  
Research purpose: competitor intelligence for Indie AuthorOS / Author Studio

## Executive summary

Codex Heim is a new, cloud-based writing and worldbuilding application built specifically for fantasy authors. It combines a manuscript editor, structured worldbuilding records, a visual timeline, character relationship mapping, writing goals, and export/backup in one web application.

Its clearest market position is "the living Codex for your Fantasy World." Unlike AI-first fiction products, Codex Heim explicitly promises not to train AI on user writing and does not advertise generative AI as part of its product. Its differentiation is genre specialization, visual interconnectedness, a fantasy-themed interface, and gamified writing consistency.

The product was still officially described as an alpha in its Terms of Service on the research date. Public evidence indicates it launched recently and remains founder-led. Independent coverage is minimal, so most available product and business information comes from Codex Heim or its founder and should be treated accordingly.

## At-a-glance fact sheet

| Item | Finding |
|---|---|
| Product | Codex Heim |
| Category | Cloud writing, worldbuilding, and planning SaaS |
| Primary audience | Fantasy authors, especially indie and first-draft writers |
| Platform | Browser-based cloud application |
| Product status | Alpha, according to Terms of Service dated August 8, 2026 |
| Operator/founder signal | Founder contact and social channels identify Brendan / `books.brendan`; a formal legal company name is not stated on the public legal pages |
| Geography/legal venue | Ohio, United States |
| Current plan | Pro, $15/month |
| Launch offer | $10 for the first month, then $15/month |
| Trial | 7 days; verified email and payment card required; auto-renews unless cancelled |
| Project allowance | Up to 10 projects; unlimited manuscript drafts |
| AI position | No advertised generative AI; explicit promise never to use user content to train, fine-tune, or evaluate AI/ML models |
| Storage model | Cloud-hosted Postgres/auth/storage/edge functions through Lovable Cloud on Supabase infrastructure; US data centers |
| Collaboration | Primarily a private single-user workspace; Sealed Scrolls provide controlled manuscript sharing |
| Export | Manuscripts: DOCX, PDF, EPUB, TXT; account backup: JSON |
| Public traction | Very limited independently verifiable data; founder publicly described it as profitable one month after launch and expressed a goal of reaching $1,000 MRR |

## Positioning and target user

Codex Heim uses unusually narrow positioning for a writing product:

- fantasy writers rather than all long-form writers
- worldbuilding-heavy fiction rather than general documents
- authors who need interconnected lore, timelines, family trees, maps, factions, and magic systems
- writers who want drafting and planning in one product
- writers motivated by streaks, goals, levels, and visible progress
- users concerned about AI training and ownership of their manuscripts

The home-page promise is not primarily "write faster." It is "organize your fantasy world" and make finishing a first draft more enjoyable. The product competes most directly with combinations of World Anvil, Campfire, Plottr, Scrivener, and lightweight writing-goal trackers.

## Product feature inventory

### Manuscript and drafting

- Rich manuscript editor
- Up to 10 book projects on Pro
- Unlimited drafts and draft switching
- Comments and navigation inside manuscripts
- Integrated worldbuilding references kept close to the editor
- Manuscript version history
- Pre-destructive draft snapshots
- In-app spellcheck using `nspell`
- Personal dictionary and word bank
- Rune markers and comments in the editor
- Export to DOCX, PDF, EPUB, and TXT

The marketing site emphasizes keeping manuscript and world context in one place. The legal documents show that version history and snapshots are retained for the lifetime of the associated manuscript or draft.

### Worldbuilding Codex

Public pages and policies identify these structured record types:

- characters
- locations
- factions
- storylines
- scenes
- timeline events
- lore
- items
- regions
- magic systems
- maps and map annotations
- tags and groups
- uploaded images and media

Records can be organized into folders and connected to each other. This breadth is a central advantage: the application models fantasy-world entities rather than treating worldbuilding as unstructured notes.

### Timeline

- Continuous visual timeline
- User-defined eras and events
- Historical, lore, inciting, battle, war, and intimate-story events can share one chronology
- Events can be linked to characters
- Search and filtering for navigation

The timeline appears designed for visual organization, not advertised automated continuity validation. Public material does not establish support for travel-time checks, impossible overlaps, dependency analysis, calendar calculations, or conflict detection.

### Lineage Canvas

- Family trees across time
- Houses
- Character-to-character relationships
- Non-family relationships such as business partners
- Interactive relationship lines

This is one of Codex Heim's more distinctive features. It translates character relationships into a genre-themed canvas rather than only storing relationship fields on character records.

### Outlining and productivity

- Outlines
- Notes
- Todos
- Writing sessions
- Daily, weekly, and monthly word goals
- Heat-map activity visualization
- Current and best writing streaks
- Daily word snapshots
- Net word-count difference and the specific words written by day

### Gamification: Author's Path

- XP earned through writing activity and milestones
- Author levels
- Level titles, such as the marketing example "Cartographer"
- Goal and manuscript-milestone rewards
- Customizable author sheet with portrait and background images

The Author's Path turns writing consistency into a role-playing-style progression loop. This is a meaningful positioning choice for fantasy audiences and a potential retention mechanism, though no independent data verifies its effect on retention.

### Sealed Scrolls

Sealed Scrolls create public, shareable manuscript snapshots for trusted readers.

- Author chooses to publish a scroll
- Link remains available until revoked or expired
- Author retains copyright
- Reader activity is exposed to the author
- Viewer country, referrer, timestamp, and hashed IP/user-agent identifiers are logged
- Readers can comment with a display name
- Scroll owners can remove comments
- Codex Heim publishes a machine-readable text-and-data-mining reservation and forbids automated scraping of scrolls

Despite wording on the marketing site describing a "private version," the legal policy says the generated URL is publicly accessible to anyone who has the link. It should therefore be understood as unlisted link sharing, not access-controlled private collaboration.

### Backup and portability

- Manuscript export: DOCX, PDF, EPUB, TXT
- Full-account JSON backup request from Settings, limited to once per 24 hours
- JSON includes manuscripts, drafts, version history, worldbuilding, notes, todos, outlines, word bank, and personal dictionary
- Backup links remain valid for 30 days
- Generated backup files are retained for up to 90 days
- Uploaded images and media are not included in JSON and must be saved separately
- When a trial or subscription ends, a complete JSON export is generated and emailed automatically
- Data remains stored after cancellation and is restored on resubscription

Portability is strong for structured text data, but media exclusion and the product's alpha status make independent backups important.

## Pricing and commercial model

### Codex Heim Pro

| Term | Detail |
|---|---|
| Standard price | $15/month in USD, excluding applicable taxes |
| Public launch promotion | $10 for the first month, then $15/month |
| Trial | 7 days |
| Card required | Yes |
| Trial conversion | Automatic charge and monthly renewal unless cancelled |
| Trial eligibility | One free trial per account/person |
| Cancellation | In-app billing portal; effective at the end of the paid period |
| Trial cancellation | Access ends when cancelled; no charge if cancelled before conversion |
| Refunds | Generally non-refundable except where law requires; billing errors reviewed in good faith |
| Failed-payment grace | 7 days |
| Price-change notice | At least 30 days for existing subscribers |

The former Starter plan is closed to new users. Existing Starter customers retain their historical price and project limit until cancellation.

### Pricing interpretation

At $15 per month, Codex Heim is priced as a focused professional hobbyist tool rather than a low-cost utility. It is less expensive than many AI-heavy subscriptions but more expensive over time than desktop software with a one-time license. The single-plan model is easy to understand, but there is no free ongoing tier and no annual discount advertised on the researched pages.

## Privacy, ownership, and data handling

### Strong commitments

- Users retain full ownership of manuscripts, worldbuilding, outlines, notes, images, and other content.
- Codex Heim claims only a limited license needed to store, process, display, and, when chosen, share content.
- User content is not sold, licensed, used for advertising, or used for external profiling.
- The operator explicitly promises never to use user content to train, fine-tune, or evaluate an AI or machine-learning model.
- Every user-facing table is described as protected by row-level security.
- Traffic uses TLS/HTTPS and stored data is encrypted at rest with platform-managed keys.
- Uploaded media uses private buckets and short-lived signed URLs.
- Manuscript and codex text is excluded from PostHog analytics.

### Infrastructure and subprocessors

- Lovable Cloud / Supabase: hosting, Postgres, authentication, file storage, and edge functions
- Stripe: billing
- Google and Apple: optional OAuth sign-in
- PostHog: product analytics and masked session replay
- MailerLite: marketing email and lifecycle fields

Primary data centers are in the United States. The policy cites Standard Contractual Clauses and the UK IDTA for relevant international transfers.

### Analytics and email tracking

- PostHog captures high-level events such as page views, clicks, and feature use.
- IP addresses are stripped before analytics storage.
- Session Replay is enabled, but all text and input fields are masked and ProseMirror manuscript/outline surfaces are excluded.
- Transactional emails contain open tracking and tracked links using hashed identifiers.
- MailerLite receives email, first name, subscription tier, signup date, recent activity date, and lifecycle stage.
- No advertising cookies, retargeting pixels, cross-site cookies, or device fingerprinting are claimed.

### Retention and deletion

- Active content remains while the account is active.
- Cancellation does not delete content.
- Account deletion removes account-scoped data within 30 days.
- Provider backups may retain copies for up to another 30 days.
- Stripe records and subscription metadata may remain for accounting and trial-enforcement purposes.
- Crash reports are de-linked rather than necessarily deleted.
- Archived over-limit projects become read-only rather than being deleted.

## Legal and operational considerations

- Minimum age is 13, or a higher local minimum.
- Terms are governed by Ohio law with venue in Ohio courts.
- The service is provided "as is."
- Total liability is capped at fees paid in the preceding 12 months.
- Users are responsible for independent backups.
- Features can change, disappear, or be disabled during alpha.
- The operator says reasonable notice will be given before removing actively used features.
- No uptime service-level agreement is offered.
- There is no public enterprise, team, or institutional agreement advertised.

## Company and traction signals

Public company information is unusually limited.

- The public contact is `brendan@codexheim.com`.
- Product social links point to Brendan's `books.brendan` accounts on TikTok, Instagram, and YouTube.
- Search results identify a founder video titled "I Launched a Writing App for Fantasy Authors."
- The founder described Codex Heim on Reddit as a SaaS built for fantasy authors and as a response to his own writing workflow.
- A Reddit post indexed in August 2026 was titled "My Niche SaaS App is Profitable, 1 Month After Launch."
- In that post's search snippet, the founder expressed a goal of reaching $1,000 MRR; this does not establish that $1,000 MRR had already been reached.
- No independently verified customer count, revenue, funding, employee count, incorporation name, or retention metric was found.
- Search visibility is currently dominated by the official site and the founder's own Reddit, TikTok, Instagram, and YouTube activity.

All revenue, profitability, adoption, and launch-timing statements above are founder-reported and not independently audited.

## Strengths

1. **Very clear niche.** "Fantasy writing and worldbuilding" is easier to understand than a broad all-writers proposition.
2. **Integrated model.** Manuscript, lore, timeline, relationships, maps, goals, and exports live in one application.
3. **Genre-native UX.** Terminology such as Codex, Sealed Scrolls, Lineage, runes, XP, and Author's Path supports the fantasy identity.
4. **Structured worldbuilding depth.** The number of entity types is stronger than generic notes-based writing tools.
5. **Lineage visualization.** Family trees and relationship lines are highly relevant to fantasy and saga writers.
6. **Writing-motivation loop.** Goals, streaks, heat maps, XP, and levels provide reasons to return daily.
7. **Explicit anti-training stance.** The privacy promise directly addresses a major author concern.
8. **Good text-data portability.** Common manuscript formats plus full JSON backup reduce lock-in.
9. **Transparent technical privacy detail.** The policy explains infrastructure, RLS, analytics masking, storage location, and deletion windows more concretely than many early products.

## Weaknesses and risks

1. **Alpha-stage reliability.** The service warns of bugs, interruptions, incomplete features, and feature changes.
2. **Cloud-only dependency.** Public pages do not establish offline support or native desktop/mobile applications.
3. **Small operator risk.** The product appears founder-led, and no larger operating entity or support team is disclosed.
4. **Limited collaboration.** Sealed Scrolls support review, but the workspace is designed as single-user and does not advertise co-author editing.
5. **No demonstrated continuity engine.** Timelines and links organize facts, but automated contradictions or impossible-event detection are not advertised.
6. **No free persistent tier.** Trial use requires a card and converts automatically.
7. **Media backup gap.** Uploaded media is excluded from the full-account JSON export.
8. **Unlisted is not private.** Anyone with a Sealed Scroll link can access it while active.
9. **Sparse independent validation.** There are few neutral reviews, benchmarks, or long-term user reports.
10. **Monthly-only pricing.** No lifetime, annual, or lower-cost current plan was visible.

## Competitive implications for Indie AuthorOS

### Where Codex Heim is ahead

- sharper fantasy-specific positioning
- more worldbuilding entity categories
- dedicated lineage/family-tree visualization
- more developed writing gamification
- link-based reader sharing with activity and comments
- EPUB and TXT alongside DOCX/PDF export
- full structured JSON account export
- highly explicit anti-AI-training messaging

### Where Indie AuthorOS can differentiate

- local-first ownership and offline resilience
- automated continuity analysis rather than only linked records
- impossible travel, overlap, POV, and chronology warnings
- reading-rhythm guidance and narrative impact tracing
- broader fiction audience without excluding fantasy
- native desktop experience
- backup health and restore verification rather than only download availability
- release and publishing workflow depth

### Product ideas worth studying

- a lineage/relationship canvas for Story Codex characters
- daily heat map and "words added today" history
- visible, user-controlled version history
- EPUB export
- a complete portable project archive, including media
- expiring beta-reader links with comments and access controls
- optional, tasteful progress levels or manuscript milestones
- clearer privacy copy explaining exactly what is and is not sent to analytics or AI services

The strongest response is not to copy the fantasy skin. It is to combine AuthorOS's deeper continuity intelligence and local-first trust with similarly legible worldbuilding connections and daily-progress feedback.

## Unknowns requiring hands-on validation

- Editor responsiveness and autosave behavior on large manuscripts
- Exact rich-text and formatting capabilities
- Import formats and migration quality
- EPUB/DOCX/PDF export fidelity
- Timeline scale, calendar flexibility, and performance
- Map upload and annotation quality
- Lineage behavior for complex or nontraditional relationships
- Accessibility and keyboard navigation
- Mobile browser usability
- Search quality across projects and entity types
- Support response time
- Actual uptime and recovery performance
- Whether project and storage limits exist beyond the stated 10-project cap
- Whether Sealed Scrolls support passwords, invitations, or download prevention
- Customer count, retention, churn, and verified revenue

## Source ledger

### Primary sources

- Codex Heim home/features: https://codexheim.com/
- Pricing: https://codexheim.com/pricing
- Terms of Service, last updated August 8, 2026: https://codexheim.com/terms
- Privacy Policy, last updated August 8, 2026: https://codexheim.com/privacy
- Founder launch video surfaced in search: https://www.youtube.com/watch?v=zJgkg9Ypmws
- Founder social profile: https://www.tiktok.com/@books.brendan
- Founder Reddit launch discussion: https://www.reddit.com/r/micro_saas/comments/1ue2k8k/i_built_a_writing_saas_for_fantasy_authors/
- Founder Reddit business update: https://www.reddit.com/r/SaaS/comments/1vj56bs/my_niche_saas_app_is_profitable_1_month_after/

### Source-quality notes

- Feature, price, legal, and privacy findings are grounded in official pages available on August 16, 2026.
- Company history and traction are mostly self-reported by the founder.
- Reddit pages were only partially accessible during research; indexed titles and snippets were used conservatively.
- No independent funding announcement, company registry record, audited metric, or substantial neutral product review was found.
- Prices, alpha status, and feature limits can change; recheck official pages before using this file for purchasing or public claims.