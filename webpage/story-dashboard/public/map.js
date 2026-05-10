const collections = [
    { key: "realms", label: "Realms" },
    { key: "cities", label: "Cities" },
    { key: "places", label: "Places" },
    { key: "characters", label: "Characters" },
    { key: "rulers", label: "Rulers" },
    { key: "factions", label: "Factions" },
    { key: "politics", label: "Politics" },
    { key: "items", label: "Items" },
    { key: "events", label: "Events" }
];

const els = {
    mapTitle: document.querySelector("#mapTitle"),
    fitButton: document.querySelector("#fitButton"),
    zoomInButton: document.querySelector("#zoomInButton"),
    zoomOutButton: document.querySelector("#zoomOutButton"),
    mapSearch: document.querySelector("#mapSearch"),
    routeFrom: document.querySelector("#routeFrom"),
    routeTo: document.querySelector("#routeTo"),
    travelMode: document.querySelector("#travelMode"),
    routeResult: document.querySelector("#routeResult"),
    mapStatus: document.querySelector("#mapStatus"),
    locationList: document.querySelector("#locationList"),
    mapViewport: document.querySelector("#mapViewport"),
    mapCanvas: document.querySelector("#mapCanvas"),
    mapImage: document.querySelector("#mapImage"),
    routeLayer: document.querySelector("#routeLayer"),
    markerLayer: document.querySelector("#markerLayer"),
    focusCard: document.querySelector("#focusCard"),
    focusType: document.querySelector("#focusType"),
    focusName: document.querySelector("#focusName"),
    focusNote: document.querySelector("#focusNote"),
    focusEntryLink: document.querySelector("#focusEntryLink")
};

const travelModes = {
    road: { label: "Road party", speed: 22, multiplier: 1.3 },
    foot: { label: "On foot", speed: 18, multiplier: 1.2 },
    mounted: { label: "Mounted", speed: 35, multiplier: 1.25 },
    wagon: { label: "Wagon", speed: 15, multiplier: 1.45 },
    river: { label: "River boat", speed: 55, multiplier: 1.1 }
};

const state = {
    bible: null,
    markers: [],
    filteredMarkers: [],
    activeMarkerId: "",
    scale: 1,
    translateX: 0,
    translateY: 0,
    mapWidth: 1800,
    mapHeight: 1200,
    dragging: false,
    dragStartX: 0,
    dragStartY: 0,
    dragOriginX: 0,
    dragOriginY: 0
};

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function collectionLabel(key) {
    return collections.find((item) => item.key === key)?.label || key;
}

function getCollection(key) {
    return Array.isArray(state.bible?.[key]) ? state.bible[key] : [];
}

function markerKey(marker) {
    return `${marker.collection}:${marker.id}`;
}

function normalizeFocus(value) {
    const focus = String(value || "").trim();
    if (!focus) return "";
    if (focus.includes(":")) return focus;

    const match = state.markers.find((marker) => marker.id === focus);
    return match ? markerKey(match) : focus;
}

function getInitialFocus() {
    const params = new URLSearchParams(window.location.search);
    return normalizeFocus(params.get("focus") || "");
}

function getMarkers() {
    return collections.flatMap((collection) =>
        getCollection(collection.key)
            .filter((entry) => entry?.map && Number.isFinite(Number(entry.map.x)) && Number.isFinite(Number(entry.map.y)))
            .map((entry) => ({
                id: entry.id,
                collection: collection.key,
                name: entry.name || entry.id,
                category: entry.category || collectionLabel(collection.key),
                kind: entry.map.kind || collection.key,
                x: Number(entry.map.x),
                y: Number(entry.map.y),
                zoom: Number(entry.map.zoom || 2.4),
                note: entry.map.note || entry.biography || "",
                searchText: `${collectionLabel(collection.key)} ${entry.name || ""} ${entry.category || ""} ${entry.map.note || ""} ${entry.biography || ""}`.toLowerCase()
            }))
    );
}

function applyTransform() {
    els.mapCanvas.style.transform = `translate(${state.translateX}px, ${state.translateY}px) scale(${state.scale})`;
    const markerUiScale = Math.max(0.55, Math.min(1.6, 1 / state.scale));
    els.mapCanvas.style.setProperty("--marker-ui-scale", markerUiScale);
}

function formatTravelTime(days) {
    if (!Number.isFinite(days) || days <= 0) return "same location";
    if (days < 0.25) return `${Math.max(1, Math.round(days * 24))} hours`;
    if (days < 1.5) return `${days.toFixed(1)} days`;
    return `${Math.round(days)} days`;
}

function getTravelScale() {
    const scale = Number(state.bible?.map?.travelScaleMilesPerMapPercent);
    return Number.isFinite(scale) && scale > 0 ? scale : 8;
}

function getRouteMarker(select) {
    return findMarker(select.value);
}

function renderRouteSelectors() {
    const currentFrom = els.routeFrom.value;
    const currentTo = els.routeTo.value;
    const options = state.markers.map((marker) =>
        `<option value="${escapeHtml(markerKey(marker))}">${escapeHtml(marker.name)}</option>`
    ).join("");

    els.routeFrom.innerHTML = options;
    els.routeTo.innerHTML = options;

    if (state.markers.length) {
        els.routeFrom.value = currentFrom && findMarker(currentFrom) ? currentFrom : markerKey(state.markers[0]);
        els.routeTo.value = currentTo && findMarker(currentTo)
            ? currentTo
            : markerKey(state.markers[Math.min(1, state.markers.length - 1)]);
    }

    updateRoute();
}

function renderRouteLine(fromMarker, toMarker) {
    if (!fromMarker || !toMarker || fromMarker === toMarker) {
        els.routeLayer.innerHTML = "";
        return;
    }

    const x1 = (fromMarker.x / 100) * state.mapWidth;
    const y1 = (fromMarker.y / 100) * state.mapHeight;
    const x2 = (toMarker.x / 100) * state.mapWidth;
    const y2 = (toMarker.y / 100) * state.mapHeight;
    els.routeLayer.innerHTML = `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"></line>`;
}

function updateRoute() {
    const fromMarker = getRouteMarker(els.routeFrom);
    const toMarker = getRouteMarker(els.routeTo);
    if (!fromMarker || !toMarker) {
        els.routeResult.textContent = "Choose two locations";
        renderRouteLine(null, null);
        return;
    }

    const dx = toMarker.x - fromMarker.x;
    const dy = toMarker.y - fromMarker.y;
    const mapPercentDistance = Math.hypot(dx, dy);
    const mode = travelModes[els.travelMode.value] || travelModes.road;
    const straightMiles = mapPercentDistance * getTravelScale();
    const routeMiles = straightMiles * mode.multiplier;
    const days = routeMiles / mode.speed;

    if (fromMarker === toMarker) {
        els.routeResult.textContent = "Same location selected.";
    }
    else {
        els.routeResult.textContent = `${fromMarker.name} to ${toMarker.name}: ${Math.round(routeMiles)} miles by ${mode.label.toLowerCase()}, about ${formatTravelTime(days)}.`;
    }
    renderRouteLine(fromMarker, toMarker);
}

function clampScale(value) {
    return Math.max(0.12, Math.min(8, value));
}

function fitMap() {
    const rect = els.mapViewport.getBoundingClientRect();
    if (!rect.width || !rect.height) return;

    const scale = Math.min(rect.width / state.mapWidth, rect.height / state.mapHeight) * 0.96;
    state.scale = clampScale(scale);
    state.translateX = (rect.width - state.mapWidth * state.scale) / 2;
    state.translateY = (rect.height - state.mapHeight * state.scale) / 2;
    applyTransform();
}

function zoomAt(clientX, clientY, nextScale) {
    const rect = els.mapViewport.getBoundingClientRect();
    const oldScale = state.scale;
    const scale = clampScale(nextScale);
    const worldX = (clientX - rect.left - state.translateX) / oldScale;
    const worldY = (clientY - rect.top - state.translateY) / oldScale;

    state.scale = scale;
    state.translateX = clientX - rect.left - worldX * scale;
    state.translateY = clientY - rect.top - worldY * scale;
    applyTransform();
}

function zoomBy(multiplier) {
    const rect = els.mapViewport.getBoundingClientRect();
    zoomAt(rect.left + rect.width / 2, rect.top + rect.height / 2, state.scale * multiplier);
}

function focusMarker(marker, updateUrl = true) {
    if (!marker) return;

    const rect = els.mapViewport.getBoundingClientRect();
    const scale = clampScale(marker.zoom || Math.max(2, state.scale));
    const pointX = (marker.x / 100) * state.mapWidth;
    const pointY = (marker.y / 100) * state.mapHeight;

    state.scale = scale;
    state.translateX = rect.width / 2 - pointX * scale;
    state.translateY = rect.height / 2 - pointY * scale;
    state.activeMarkerId = markerKey(marker);
    applyTransform();
    renderMarkers();
    renderLocationList();
    renderFocusCard(marker);

    if (updateUrl) {
        const url = new URL(window.location.href);
        url.searchParams.set("focus", state.activeMarkerId);
        window.history.replaceState({}, "", url);
    }
}

function renderFocusCard(marker) {
    els.focusCard.hidden = false;
    els.focusType.textContent = `${collectionLabel(marker.collection)} / ${marker.category}`;
    els.focusName.textContent = marker.name;
    els.focusNote.textContent = marker.note || "Map marker";
    els.focusEntryLink.href = `/?entry=${encodeURIComponent(marker.collection + ":" + marker.id)}`;
}

function renderMarkers() {
    els.markerLayer.innerHTML = state.markers.map((marker) => {
        const active = markerKey(marker) === state.activeMarkerId ? " active" : "";
        return `
            <button type="button" class="map-marker ${escapeHtml(marker.kind)}${active}" data-marker="${escapeHtml(markerKey(marker))}" style="left:${marker.x}%; top:${marker.y}%;">
                <span class="marker-pin"></span>
                <span class="marker-label">${escapeHtml(marker.name)}</span>
            </button>
        `;
    }).join("");
}

function filterMarkers() {
    const query = els.mapSearch.value.trim().toLowerCase();
    state.filteredMarkers = query
        ? state.markers.filter((marker) => marker.searchText.includes(query))
        : state.markers;
    renderLocationList();
}

function renderLocationList() {
    const markers = state.filteredMarkers.length ? state.filteredMarkers : state.markers;
    if (!markers.length) {
        els.locationList.innerHTML = `<div class="empty-state"><strong>No map markers yet</strong></div>`;
        return;
    }

    els.locationList.innerHTML = markers.map((marker) => {
        const active = markerKey(marker) === state.activeMarkerId ? " active" : "";
        return `
            <button type="button" class="location-row${active}" data-marker="${escapeHtml(markerKey(marker))}">
                <span>${escapeHtml(marker.name)}</span>
                <small>${escapeHtml(collectionLabel(marker.collection))} / ${escapeHtml(marker.category)}</small>
            </button>
        `;
    }).join("");
}

function findMarker(key) {
    const normalized = normalizeFocus(key);
    return state.markers.find((marker) => markerKey(marker) === normalized || marker.id === normalized);
}

function handlePointerDown(event) {
    if (event.button !== 0) return;
    if (event.target.closest(".map-marker")) return;

    state.dragging = true;
    state.dragStartX = event.clientX;
    state.dragStartY = event.clientY;
    state.dragOriginX = state.translateX;
    state.dragOriginY = state.translateY;
    els.mapViewport.classList.add("dragging");
    els.mapViewport.setPointerCapture(event.pointerId);
}

function handlePointerMove(event) {
    if (!state.dragging) return;
    state.translateX = state.dragOriginX + event.clientX - state.dragStartX;
    state.translateY = state.dragOriginY + event.clientY - state.dragStartY;
    applyTransform();
}

function handlePointerUp(event) {
    if (!state.dragging) return;
    state.dragging = false;
    els.mapViewport.classList.remove("dragging");
    try {
        els.mapViewport.releasePointerCapture(event.pointerId);
    }
    catch {
        return;
    }
}

async function loadMap() {
    const response = await fetch(`/api/story-bible?at=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error("Could not load story bible.");

    state.bible = await response.json();
    const mapImage = state.bible?.map?.image || {};
    els.mapTitle.textContent = mapImage.name || "Interactive Map";
    els.mapImage.src = mapImage.src || "/assets/maps/world-map.svg";
    els.mapStatus.textContent = state.bible?.map?.notes || "Map ready";

    state.markers = getMarkers();
    state.filteredMarkers = state.markers;
    renderMarkers();
    renderRouteSelectors();
    renderLocationList();

    const focus = getInitialFocus();
    const focusedMarker = focus ? findMarker(focus) : state.markers[0];
    if (focusedMarker) {
        focusMarker(focusedMarker, Boolean(focus));
    }
}

els.mapImage.addEventListener("load", () => {
    state.mapWidth = els.mapImage.naturalWidth || 1800;
    state.mapHeight = els.mapImage.naturalHeight || 1200;
    els.mapCanvas.style.width = `${state.mapWidth}px`;
    els.mapCanvas.style.height = `${state.mapHeight}px`;
    els.routeLayer.setAttribute("viewBox", `0 0 ${state.mapWidth} ${state.mapHeight}`);
    fitMap();
    updateRoute();

    const focusedMarker = state.activeMarkerId ? findMarker(state.activeMarkerId) : findMarker(getInitialFocus());
    if (focusedMarker) {
        window.setTimeout(() => focusMarker(focusedMarker, false), 40);
    }
});

els.mapViewport.addEventListener("wheel", (event) => {
    event.preventDefault();
    const multiplier = event.deltaY < 0 ? 1.16 : 0.86;
    zoomAt(event.clientX, event.clientY, state.scale * multiplier);
}, { passive: false });

els.mapViewport.addEventListener("pointerdown", handlePointerDown);
els.mapViewport.addEventListener("pointermove", handlePointerMove);
els.mapViewport.addEventListener("pointerup", handlePointerUp);
els.mapViewport.addEventListener("pointercancel", handlePointerUp);

els.markerLayer.addEventListener("click", (event) => {
    const button = event.target.closest("[data-marker]");
    if (!button) return;
    focusMarker(findMarker(button.dataset.marker));
});

els.locationList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-marker]");
    if (!button) return;
    focusMarker(findMarker(button.dataset.marker));
});

els.mapSearch.addEventListener("input", filterMarkers);
els.routeFrom.addEventListener("change", updateRoute);
els.routeTo.addEventListener("change", updateRoute);
els.travelMode.addEventListener("change", updateRoute);
els.fitButton.addEventListener("click", fitMap);
els.zoomInButton.addEventListener("click", () => zoomBy(1.2));
els.zoomOutButton.addEventListener("click", () => zoomBy(0.82));
window.addEventListener("resize", fitMap);

loadMap().catch((error) => {
    els.mapStatus.textContent = error.message || "Map unavailable";
});
