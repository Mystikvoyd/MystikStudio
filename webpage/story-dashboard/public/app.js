const collections = [
    { key: "realms", label: "Realms" },
    { key: "characters", label: "Characters" },
    { key: "cities", label: "Cities" },
    { key: "places", label: "Places" },
    { key: "rulers", label: "Rulers" },
    { key: "politics", label: "Politics" },
    { key: "factions", label: "Factions" },
    { key: "visualReferences", label: "Visual Refs" },
    { key: "items", label: "Items" },
    { key: "events", label: "Events" },
    { key: "openQuestions", label: "Questions" }
];

const els = {
    bookTitleHeading: document.querySelector("#bookTitleHeading"),
    connectionStatus: document.querySelector("#connectionStatus"),
    liveDot: document.querySelector("#liveDot"),
    refreshButton: document.querySelector("#refreshButton"),
    searchInput: document.querySelector("#searchInput"),
    categoryTabs: document.querySelector("#categoryTabs"),
    entityList: document.querySelector("#entityList"),
    portraitButton: document.querySelector("#portraitButton"),
    entityImage: document.querySelector("#entityImage"),
    entityCategory: document.querySelector("#entityCategory"),
    entityName: document.querySelector("#entityName"),
    mapLink: document.querySelector("#mapLink"),
    entityTags: document.querySelector("#entityTags"),
    entityBiography: document.querySelector("#entityBiography"),
    propertiesTitle: document.querySelector("#propertiesTitle"),
    physicalGrid: document.querySelector("#physicalGrid"),
    promptBox: document.querySelector("#promptBox"),
    copyPromptButton: document.querySelector("#copyPromptButton"),
    referenceGallery: document.querySelector("#referenceGallery"),
    customSectionsWrap: document.querySelector("#customSectionsWrap"),
    customSections: document.querySelector("#customSections"),
    crossReferenceSection: document.querySelector("#crossReferenceSection"),
    crossReferenceGrid: document.querySelector("#crossReferenceGrid"),
    detailFeed: document.querySelector("#detailFeed"),
    worldGrid: document.querySelector("#worldGrid"),
    intakeForm: document.querySelector("#intakeForm"),
    intakeCollection: document.querySelector("#intakeCollection"),
    intakeName: document.querySelector("#intakeName"),
    imageSrc: document.querySelector("#imageSrc"),
    imagePrompt: document.querySelector("#imagePrompt"),
    biographyInput: document.querySelector("#biographyInput"),
    heightInput: document.querySelector("#heightInput"),
    ageInput: document.querySelector("#ageInput"),
    buildInput: document.querySelector("#buildInput"),
    hairInput: document.querySelector("#hairInput"),
    eyesInput: document.querySelector("#eyesInput"),
    voiceInput: document.querySelector("#voiceInput"),
    scaleInput: document.querySelector("#scaleInput"),
    aiPromptInput: document.querySelector("#aiPromptInput"),
    detailsInput: document.querySelector("#detailsInput"),
    tagsInput: document.querySelector("#tagsInput"),
    formStatus: document.querySelector("#formStatus"),
    realmCount: document.querySelector("#realmCount"),
    characterCount: document.querySelector("#characterCount"),
    cityCount: document.querySelector("#cityCount"),
    rulerCount: document.querySelector("#rulerCount"),
    politicsCount: document.querySelector("#politicsCount"),
    visualReferenceCount: document.querySelector("#visualReferenceCount"),
    totalWords: document.querySelector("#totalWords"),
    referenceWords: document.querySelector("#referenceWords"),
    draftProgressText: document.querySelector("#draftProgressText"),
    draftProgressBar: document.querySelector("#draftProgressBar"),
    chapterList: document.querySelector("#chapterList"),
    imageModal: document.querySelector("#imageModal"),
    modalTitle: document.querySelector("#modalTitle"),
    modalImage: document.querySelector("#modalImage"),
    modalZoom: document.querySelector("#modalZoom"),
    modalZoomText: document.querySelector("#modalZoomText"),
    modalDownload: document.querySelector("#modalDownload"),
    modalClose: document.querySelector("#modalClose")
};

const state = {
    bible: null,
    progress: null,
    selectedCollection: "realms",
    selectedId: "the-last-ward",
    searchQuery: "",
    formDirty: false,
    routeApplied: false
};

function formatNumber(value) {
    return new Intl.NumberFormat().format(value || 0);
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function labelize(value) {
    return String(value || "")
        .replace(/([A-Z])/g, " $1")
        .replace(/[_-]+/g, " ")
        .trim();
}

function timeAgo(iso) {
    if (!iso) return "";
    const then = new Date(iso).getTime();
    const seconds = Math.max(0, Math.round((Date.now() - then) / 1000));
    if (seconds < 5) return "just now";
    if (seconds < 60) return `${seconds}s ago`;
    const minutes = Math.round(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.round(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.round(hours / 24)}d ago`;
}

function setConnection(stateName, text) {
    els.connectionStatus.textContent = text;
    els.liveDot.classList.remove("ok", "error");
    if (stateName) els.liveDot.classList.add(stateName);
}

function getCollection(key) {
    return Array.isArray(state.bible?.[key]) ? state.bible[key] : [];
}

function collectionLabel(key) {
    return collections.find((item) => item.key === key)?.label || key;
}

function latestText(entries) {
    if (!Array.isArray(entries) || !entries.length) return "";
    return entries[entries.length - 1]?.text || "";
}

function findEntryLocation(id) {
    for (const collection of collections) {
        const entry = getCollection(collection.key).find((item) => item.id === id);
        if (entry) return { collection: collection.key, entry };
    }
    return null;
}

function getFirstEntity() {
    for (const collection of collections) {
        const entry = getCollection(collection.key)[0];
        if (entry) return { collection: collection.key, entry };
    }
    return null;
}

function ensureSelection() {
    const current = getCollection(state.selectedCollection).find((entry) => entry.id === state.selectedId);
    if (current) return current;

    const foundById = findEntryLocation(state.selectedId);
    if (foundById) {
        state.selectedCollection = foundById.collection;
        return foundById.entry;
    }

    const firstInCollection = getCollection(state.selectedCollection)[0];
    if (firstInCollection) {
        state.selectedId = firstInCollection.id;
        return firstInCollection;
    }

    const first = getFirstEntity();
    if (first) {
        state.selectedCollection = first.collection;
        state.selectedId = first.entry.id;
        return first.entry;
    }

    return null;
}

function getSelectedEntity() {
    return ensureSelection();
}

function applyRouteFocus() {
    if (state.routeApplied || !state.bible) return;
    state.routeApplied = true;

    const params = new URLSearchParams(window.location.search);
    const entry = params.get("entry") || "";
    const [collection, id] = entry.split(":");
    if (!collection || !id) return;

    const target = getCollection(collection).find((item) => item.id === id);
    if (!target) return;

    state.selectedCollection = collection;
    state.selectedId = id;
}

function entrySearchText(entry, collectionKey) {
    return `${collectionLabel(collectionKey)} ${JSON.stringify(entry)}`.toLowerCase();
}

function getSearchResults() {
    const query = state.searchQuery.trim().toLowerCase();
    if (!query) return [];

    return collections.flatMap((collection) =>
        getCollection(collection.key)
            .filter((entry) => entrySearchText(entry, collection.key).includes(query))
            .map((entry) => ({ collection: collection.key, entry }))
    );
}

function fillIntakeFromEntity(entity) {
    if (!entity) return;
    if (state.formDirty) return;
    els.intakeCollection.value = state.selectedCollection;
    els.intakeName.value = entity.name || "";
    els.imageSrc.value = entity.image?.src || "";
    els.imagePrompt.value = entity.image?.prompt || "";
    els.tagsInput.value = Array.isArray(entity.tags) ? entity.tags.join(", ") : "";
}

function renderSummary() {
    const progress = state.progress || {};
    els.bookTitleHeading.textContent = state.bible?.title || progress.config?.title || "Story Bible";
    els.realmCount.textContent = formatNumber(getCollection("realms").length);
    els.characterCount.textContent = formatNumber(getCollection("characters").length);
    els.cityCount.textContent = formatNumber(getCollection("cities").length);
    els.rulerCount.textContent = formatNumber(getCollection("rulers").length);
    els.politicsCount.textContent = formatNumber(getCollection("politics").length);
    els.visualReferenceCount.textContent = formatNumber(getCollection("visualReferences").length);
    els.totalWords.textContent = formatNumber(progress.totalWords);
    els.referenceWords.textContent = formatNumber(progress.reference?.referenceWords);
    els.draftProgressText.textContent = `${progress.draftProgress || 0}% of draft target`;
    els.draftProgressBar.style.width = `${Math.max(0, Math.min(100, progress.draftProgress || 0))}%`;
}

function renderTabs() {
    els.categoryTabs.innerHTML = collections.map((collection) => {
        const count = getCollection(collection.key).length;
        const active = collection.key === state.selectedCollection ? " active" : "";
        return `
            <button type="button" class="tab-button${active}" data-collection="${collection.key}">
                <span>${escapeHtml(collection.label)}</span>
                <strong>${formatNumber(count)}</strong>
            </button>
        `;
    }).join("");
}

function renderEntityList() {
    const query = state.searchQuery.trim();
    if (query) {
        const results = getSearchResults();
        if (!results.length) {
            els.entityList.innerHTML = `<div class="empty-state"><strong>No matches</strong><span>Try another name or phrase.</span></div>`;
            return;
        }

        els.entityList.innerHTML = results.map(({ collection, entry }) => {
            const active = collection === state.selectedCollection && entry.id === state.selectedId ? " active" : "";
            return `
                <button type="button" class="entity-row${active}" data-collection="${collection}" data-id="${escapeHtml(entry.id)}">
                    <span>${escapeHtml(entry.name)}</span>
                    <small>${escapeHtml(collectionLabel(collection))} / ${escapeHtml(entry.category || entry.status || "")}</small>
                </button>
            `;
        }).join("");
        return;
    }

    const entries = getCollection(state.selectedCollection);
    if (!entries.length) {
        els.entityList.innerHTML = `<div class="empty-state"><strong>No entries yet</strong></div>`;
        return;
    }

    els.entityList.innerHTML = entries.map((entry) => {
        const active = entry.id === state.selectedId ? " active" : "";
        const tags = Array.isArray(entry.tags) ? entry.tags.slice(0, 2).join(" / ") : "";
        return `
            <button type="button" class="entity-row${active}" data-id="${escapeHtml(entry.id)}">
                <span>${escapeHtml(entry.name)}</span>
                <small>${escapeHtml(entry.category || tags || entry.status || "")}</small>
            </button>
        `;
    }).join("");
}

function stringifyValue(value) {
    if (Array.isArray(value)) {
        return value.map((item) => stringifyValue(item)).filter(Boolean).join("; ");
    }

    if (value && typeof value === "object") {
        return Object.entries(value)
            .map(([key, nested]) => `${labelize(key)}: ${stringifyValue(nested)}`)
            .join("; ");
    }

    return String(value ?? "").trim();
}

function getPropertyObject(entity) {
    const physical = entity?.physical || {};
    const properties = entity?.properties || {};
    const stats = entity?.stats || {};

    if (Object.keys(physical).length) return { title: "Physical Properties", values: physical };
    if (Object.keys(properties).length) return { title: "Properties", values: properties };
    if (Object.keys(stats).length) return { title: "Properties", values: stats };
    return { title: "Properties", values: {} };
}

function renderProperties(entity) {
    const propertySet = getPropertyObject(entity);
    els.propertiesTitle.textContent = propertySet.title;

    const entries = Object.entries(propertySet.values)
        .map(([key, value]) => [key, stringifyValue(value)])
        .filter(([, value]) => value);

    if (!entries.length) {
        els.physicalGrid.innerHTML = `<div class="empty-state"><strong>No properties logged</strong></div>`;
        return;
    }

    els.physicalGrid.innerHTML = entries.map(([key, value]) => `
        <div class="property-item">
            <span>${escapeHtml(labelize(key))}</span>
            <strong>${escapeHtml(value)}</strong>
        </div>
    `).join("");
}

function renderDetails(entity) {
    const details = [
        ...(Array.isArray(entity?.importantDetails) ? entity.importantDetails : []),
        ...(Array.isArray(entity?.physicalNotes) ? entity.physicalNotes : [])
    ];

    if (!details.length) {
        els.detailFeed.innerHTML = `<div class="empty-state"><strong>No details logged</strong></div>`;
        return;
    }

    els.detailFeed.innerHTML = details.slice().reverse().map((detail) => `
        <article class="feed-item">
            <p>${escapeHtml(detail.text || detail)}</p>
            <span>${detail.at ? timeAgo(detail.at) : ""}</span>
        </article>
    `).join("");
}

function sanitizeFilename(value, src) {
    const fallback = String(src || "image").split("/").filter(Boolean).pop() || "image.png";
    const clean = String(value || fallback)
        .replace(/\.[a-z0-9]{2,5}$/i, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");

    const extension = (String(src || "").match(/\.[a-z0-9]{2,5}(?=$|\?)/i)?.[0] || ".png").toLowerCase();
    return `${clean || "image"}${extension}`;
}

function imageButton(src, title, imgClass = "") {
    if (!src) return "";
    const filename = sanitizeFilename(title, src);
    return `
        <button type="button" class="image-open-button ${imgClass}" data-image-src="${escapeHtml(src)}" data-image-title="${escapeHtml(title || filename)}" data-image-filename="${escapeHtml(filename)}">
            <img src="${escapeHtml(src)}" alt="${escapeHtml(title || "Visual reference")}">
        </button>
    `;
}

function getImageReferences(entity) {
    const references = [];
    for (const key of ["visualReferences", "conceptArt", "images"]) {
        if (Array.isArray(entity?.[key])) {
            references.push(...entity[key]);
        }
    }
    return references.filter((reference) => reference?.src);
}

function renderReferenceGallery(entity) {
    const references = getImageReferences(entity);
    if (!references.length) {
        els.referenceGallery.innerHTML = `<div class="empty-state"><strong>No concept art or references attached</strong></div>`;
        return;
    }

    els.referenceGallery.innerHTML = references.map((reference) => `
        <article class="reference-card">
            ${imageButton(reference.src, reference.title || reference.name || "Visual reference", "reference-image")}
            <div>
                <strong>${escapeHtml(reference.title || reference.name || "Visual reference")}</strong>
                <p>${escapeHtml(reference.notes || reference.description || "")}</p>
            </div>
        </article>
    `).join("");
}

function renderFactItems(items) {
    if (!Array.isArray(items) || !items.length) return "";
    return `
        <div class="record-facts">
            ${items.map((item) => `
                <div>
                    <span>${escapeHtml(item.label || item.name || "")}</span>
                    <strong>${escapeHtml(stringifyValue(item.value ?? item.text ?? item.description ?? ""))}</strong>
                </div>
            `).join("")}
        </div>
    `;
}

function renderBulletList(list) {
    if (!Array.isArray(list) || !list.length) return "";
    return `
        <ul class="record-list">
            ${list.map((item) => `<li>${escapeHtml(stringifyValue(item))}</li>`).join("")}
        </ul>
    `;
}

function renderRecordEntries(entries) {
    if (!Array.isArray(entries) || !entries.length) return "";

    return `
        <div class="record-entry-grid">
            ${entries.map((entry) => {
                const lines = [];
                for (const key of ["role", "population", "type", "purpose", "function", "identity", "strategicValue", "includes"]) {
                    if (entry[key]) lines.push(`<p><span>${escapeHtml(labelize(key))}:</span> ${escapeHtml(stringifyValue(entry[key]))}</p>`);
                }
                const itemFacts = renderFactItems(entry.items);
                const bullets = renderBulletList(entry.duties || entry.members || entry.list);
                return `
                    <article class="record-entry">
                        <h5>${escapeHtml(entry.name || entry.title || "")}</h5>
                        ${entry.description ? `<p>${escapeHtml(entry.description)}</p>` : ""}
                        ${lines.join("")}
                        ${itemFacts}
                        ${bullets}
                    </article>
                `;
            }).join("")}
        </div>
    `;
}

function renderCustomSection(section, nested = false) {
    return `
        <article class="${nested ? "record-subsection" : "record-section"}">
            <h4>${escapeHtml(section.title || section.name || "")}</h4>
            ${section.body ? `<p>${escapeHtml(section.body)}</p>` : ""}
            ${renderFactItems(section.items)}
            ${renderBulletList(section.list)}
            ${renderRecordEntries(section.entries)}
            ${Array.isArray(section.subsections) && section.subsections.length ? `
                <div class="record-subsections">
                    ${section.subsections.map((item) => renderCustomSection(item, true)).join("")}
                </div>
            ` : ""}
        </article>
    `;
}

function renderCustomSections(entity) {
    const sections = Array.isArray(entity?.sections) ? entity.sections : [];
    els.customSectionsWrap.hidden = !sections.length;

    if (!sections.length) {
        els.customSections.innerHTML = "";
        return;
    }

    els.customSections.innerHTML = sections.map((section) => renderCustomSection(section)).join("");
}

function renderCrossReferences(entity) {
    const refs = Array.isArray(entity?.crossReferences) ? entity.crossReferences : [];
    els.crossReferenceSection.hidden = !refs.length;

    if (!refs.length) {
        els.crossReferenceGrid.innerHTML = "";
        return;
    }

    els.crossReferenceGrid.innerHTML = refs.map((ref) => {
        const collection = ref.collection || "";
        const id = ref.id || "";
        const linked = collection && id;
        return `
            <${linked ? "button" : "div"} type="button" class="xref-card" ${linked ? `data-collection="${escapeHtml(collection)}" data-id="${escapeHtml(id)}"` : ""}>
                <strong>${escapeHtml(ref.label || ref.name || id || collection)}</strong>
                <span>${escapeHtml(ref.note || collectionLabel(collection) || "")}</span>
            </${linked ? "button" : "div"}>
        `;
    }).join("");
}

function buildPrompt(entity) {
    const prompt = latestText(entity?.aiPrompts);
    const imagePrompt = entity?.image?.prompt || "";
    const propertySet = getPropertyObject(entity);
    const properties = Object.entries(propertySet.values || {})
        .map(([key, value]) => [key, stringifyValue(value)])
        .filter(([, value]) => value)
        .map(([key, value]) => `${labelize(key)}: ${value}`)
        .join("\n");

    return [
        `Entry: ${entity?.name || ""}`,
        entity?.category ? `Category: ${entity.category}` : "",
        entity?.biography ? `Description:\n${entity.biography}` : "",
        properties ? `${propertySet.title}:\n${properties}` : "",
        imagePrompt ? `Image prompt:\n${imagePrompt}` : "",
        prompt ? `Writing prompt:\n${prompt}` : ""
    ].filter(Boolean).join("\n\n");
}

function renderDetail() {
    const entity = getSelectedEntity();
    if (!entity) {
        els.entityName.textContent = "No entry selected";
        els.entityBiography.textContent = "";
        els.entityImage.removeAttribute("src");
        els.portraitButton.removeAttribute("data-image-src");
        els.physicalGrid.innerHTML = "";
        els.promptBox.textContent = "";
        els.detailFeed.innerHTML = "";
        els.customSectionsWrap.hidden = true;
        els.crossReferenceSection.hidden = true;
        return;
    }

    state.selectedId = entity.id;
    els.entityCategory.textContent = entity.category || collectionLabel(state.selectedCollection);
    els.entityName.textContent = entity.name || "";
    els.entityBiography.textContent = entity.biography || "";

    const imageSrc = entity.image?.src || "";
    const imageTitle = `${entity.name || "Entry"} portrait`;
    if (imageSrc) {
        els.entityImage.hidden = false;
        els.entityImage.src = imageSrc;
        els.entityImage.alt = imageTitle;
        els.portraitButton.disabled = false;
        els.portraitButton.classList.remove("empty-portrait");
        els.portraitButton.dataset.imageSrc = imageSrc;
        els.portraitButton.dataset.imageTitle = imageTitle;
        els.portraitButton.dataset.imageFilename = sanitizeFilename(entity.name || "portrait", imageSrc);
    }
    else {
        els.entityImage.hidden = true;
        els.entityImage.removeAttribute("src");
        els.portraitButton.disabled = true;
        els.portraitButton.classList.add("empty-portrait");
        els.portraitButton.removeAttribute("data-image-src");
        els.portraitButton.removeAttribute("data-image-title");
        els.portraitButton.removeAttribute("data-image-filename");
    }

    els.entityTags.innerHTML = (Array.isArray(entity.tags) ? entity.tags : []).map((tag) => `<span>${escapeHtml(tag)}</span>`).join("");
    els.promptBox.textContent = buildPrompt(entity);
    if (entity.map && Number.isFinite(Number(entity.map.x)) && Number.isFinite(Number(entity.map.y))) {
        els.mapLink.hidden = false;
        els.mapLink.href = `/map.html?focus=${encodeURIComponent(state.selectedCollection + ":" + entity.id)}`;
    }
    else {
        els.mapLink.hidden = true;
        els.mapLink.href = "/map.html";
    }
    renderProperties(entity);
    renderReferenceGallery(entity);
    renderCustomSections(entity);
    renderCrossReferences(entity);
    renderDetails(entity);
    fillIntakeFromEntity(entity);
}

function renderWorldGrid() {
    const featured = collections.filter((collection) => collection.key !== state.selectedCollection);
    els.worldGrid.innerHTML = featured.map((collection) => {
        const entries = getCollection(collection.key).slice(0, 5);
        return `
            <section class="panel world-panel">
                <div class="panel-heading compact">
                    <div>
                        <p class="eyebrow">${escapeHtml(collection.label)}</p>
                        <h2>${formatNumber(getCollection(collection.key).length)} tracked</h2>
                    </div>
                </div>
                <div class="mini-list">
                    ${entries.length ? entries.map((entry) => `
                        <button type="button" data-collection="${collection.key}" data-id="${escapeHtml(entry.id)}">
                            <strong>${escapeHtml(entry.name)}</strong>
                            <span>${escapeHtml(entry.category || entry.status || "")}</span>
                        </button>
                    `).join("") : `<div class="empty-state small"><strong>Empty</strong></div>`}
                </div>
            </section>
        `;
    }).join("");
}

function renderChapters() {
    const chapters = state.progress?.chapters || [];
    if (!chapters.length) {
        els.chapterList.innerHTML = `<div class="empty-state"><strong>No manuscript files found</strong></div>`;
        return;
    }

    els.chapterList.innerHTML = chapters.map((chapter) => `
        <div class="chapter-row">
            <div>
                <strong>${escapeHtml(chapter.name)}</strong>
                <span>${escapeHtml(chapter.file)}</span>
            </div>
            <em>${formatNumber(chapter.words)} words</em>
        </div>
    `).join("");
}

function render() {
    ensureSelection();
    renderSummary();
    renderTabs();
    renderEntityList();
    renderDetail();
    renderWorldGrid();
    renderChapters();
}

async function refresh() {
    try {
        const [progressResponse, bibleResponse] = await Promise.all([
            fetch(`/api/progress?at=${Date.now()}`, { cache: "no-store" }),
            fetch(`/api/story-bible?at=${Date.now()}`, { cache: "no-store" })
        ]);

        if (!progressResponse.ok || !bibleResponse.ok) throw new Error("request failed");

        state.progress = await progressResponse.json();
        state.bible = await bibleResponse.json();
        applyRouteFocus();
        render();
        setConnection("ok", `Live ${timeAgo(state.progress.updatedAt)}`);
    }
    catch (error) {
        setConnection("error", "Offline");
    }
}

function collectPhysical() {
    return {
        height: els.heightInput.value,
        age: els.ageInput.value,
        build: els.buildInput.value,
        hair: els.hairInput.value,
        eyes: els.eyesInput.value,
        voice: els.voiceInput.value,
        scaleNotes: els.scaleInput.value
    };
}

function clearAppendFields() {
    state.formDirty = false;
    els.biographyInput.value = "";
    els.aiPromptInput.value = "";
    els.detailsInput.value = "";
    els.heightInput.value = "";
    els.ageInput.value = "";
    els.buildInput.value = "";
    els.hairInput.value = "";
    els.eyesInput.value = "";
    els.voiceInput.value = "";
    els.scaleInput.value = "";
}

async function saveIntake(event) {
    event.preventDefault();
    els.formStatus.textContent = "Saving...";
    state.formDirty = false;

    const payload = {
        collection: els.intakeCollection.value,
        name: els.intakeName.value,
        imageSrc: els.imageSrc.value,
        imagePrompt: els.imagePrompt.value,
        biography: els.biographyInput.value,
        aiPrompt: els.aiPromptInput.value,
        details: els.detailsInput.value,
        physical: collectPhysical(),
        tags: els.tagsInput.value
    };

    try {
        const response = await fetch("/api/story-bible/entity", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });

        if (!response.ok) throw new Error("save failed");

        const result = await response.json();
        state.selectedCollection = result.collection || payload.collection;
        state.selectedId = result.entity?.id || state.selectedId;
        clearAppendFields();
        els.formStatus.textContent = result.created ? "Created." : "Appended.";
        await refresh();
        window.setTimeout(() => {
            if (els.formStatus.textContent === "Created." || els.formStatus.textContent === "Appended.") {
                els.formStatus.textContent = "";
            }
        }, 1600);
    }
    catch (error) {
        els.formStatus.textContent = "Could not save.";
    }
}

function selectEntry(collection, id) {
    state.selectedCollection = collection || state.selectedCollection;
    state.selectedId = id || state.selectedId;
    state.formDirty = false;
    render();
}

function updateModalZoom() {
    const zoom = Number(els.modalZoom.value || 1);
    els.modalImage.style.width = `${Math.round(zoom * 100)}%`;
    els.modalZoomText.textContent = `${Math.round(zoom * 100)}%`;
}

function openImageViewer(src, title, filename) {
    if (!src) return;
    els.modalTitle.textContent = title || "Image";
    els.modalImage.src = src;
    els.modalImage.alt = title || "Image";
    els.modalDownload.href = src;
    els.modalDownload.download = filename || sanitizeFilename(title, src);
    els.modalZoom.value = "1";
    updateModalZoom();
    els.imageModal.hidden = false;
    document.body.classList.add("modal-open");
}

function closeImageViewer() {
    els.imageModal.hidden = true;
    els.modalImage.removeAttribute("src");
    document.body.classList.remove("modal-open");
}

els.categoryTabs.addEventListener("click", (event) => {
    const button = event.target.closest("[data-collection]");
    if (!button) return;
    state.searchQuery = "";
    els.searchInput.value = "";
    state.selectedCollection = button.dataset.collection;
    state.selectedId = getCollection(state.selectedCollection)[0]?.id || "";
    state.formDirty = false;
    render();
});

els.entityList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-id]");
    if (!button) return;
    selectEntry(button.dataset.collection || state.selectedCollection, button.dataset.id);
});

els.worldGrid.addEventListener("click", (event) => {
    const button = event.target.closest("[data-collection][data-id]");
    if (!button) return;
    selectEntry(button.dataset.collection, button.dataset.id);
    window.scrollTo({ top: 0, behavior: "smooth" });
});

els.crossReferenceGrid.addEventListener("click", (event) => {
    const button = event.target.closest("[data-collection][data-id]");
    if (!button) return;
    selectEntry(button.dataset.collection, button.dataset.id);
    window.scrollTo({ top: 0, behavior: "smooth" });
});

document.addEventListener("click", (event) => {
    const imageButtonElement = event.target.closest("[data-image-src]");
    if (!imageButtonElement) return;
    openImageViewer(
        imageButtonElement.dataset.imageSrc,
        imageButtonElement.dataset.imageTitle,
        imageButtonElement.dataset.imageFilename
    );
});

els.copyPromptButton.addEventListener("click", async () => {
    try {
        await navigator.clipboard.writeText(els.promptBox.textContent);
        els.copyPromptButton.textContent = "Copied";
        window.setTimeout(() => {
            els.copyPromptButton.textContent = "Copy";
        }, 1200);
    }
    catch {
        els.copyPromptButton.textContent = "Copy failed";
    }
});

els.searchInput.addEventListener("input", () => {
    state.searchQuery = els.searchInput.value;
    renderEntityList();
});

els.refreshButton.addEventListener("click", refresh);
els.intakeForm.addEventListener("submit", saveIntake);
els.intakeForm.addEventListener("input", () => {
    state.formDirty = true;
});

els.modalZoom.addEventListener("input", updateModalZoom);
els.modalClose.addEventListener("click", closeImageViewer);
els.imageModal.addEventListener("click", (event) => {
    if (event.target === els.imageModal) closeImageViewer();
});

document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !els.imageModal.hidden) closeImageViewer();
});

refresh();
window.setInterval(refresh, 4000);
