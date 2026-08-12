import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Layers, MapPin, AlertTriangle, Radio, Navigation, Compass } from 'lucide-react';

export default function OpenStreetMap({
  workers = [],
  selectedWorker = null,
  onSelectWorker = () => {}
}) {
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const markersRef = useRef({});
  const [mapTheme, setMapTheme] = useState('dark'); // 'dark' (CartoDB Dark Matter OSM) or 'standard' (OSM Standard)
  const tileLayerRef = useRef(null);

  // Default site center coords (Bangkok Construction Site Perimeter: 13.7563 N, 100.5018 E)
  const defaultCenter = [13.7563, 100.5018];
  const defaultZoom = 17;

  // Tile URL mapping
  const tileSources = {
    dark: {
      url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
    },
    standard: {
      url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }
  };

  // Initialize Leaflet Map
  useEffect(() => {
    if (!mapContainerRef.current) return;

    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        center: defaultCenter,
        zoom: defaultZoom,
        zoomControl: false
      });

      // Add Zoom Control to Top Right
      L.control.zoom({ position: 'topright' }).addTo(map);

      // Initial Tile Layer
      const initialSource = tileSources[mapTheme];
      tileLayerRef.current = L.tileLayer(initialSource.url, {
        attribution: initialSource.attribution,
        maxZoom: 20,
        subdomains: 'abcd'
      }).addTo(map);

      // Construction Site Zone Overlay Polygons on OpenStreetMap
      // 1. Zone A: Scaffold Area
      const zoneAPolygon = L.polygon([
        [13.7570, 100.5008],
        [13.7572, 100.5028],
        [13.7558, 100.5028],
        [13.7558, 100.5008]
      ], {
        color: '#475569',
        weight: 2,
        dashArray: '6, 6',
        fillColor: '#1E293B',
        fillOpacity: 0.25
      }).addTo(map);
      zoneAPolygon.bindTooltip("Scaffold Zone A (High Altitude)", { permanent: true, direction: "top", className: "osm-zone-tooltip" });

      // 2. Zone B: Heavy Crane Lift Hazard Zone
      const zoneBCircle = L.circle([13.7566, 100.5024], {
        radius: 45,
        color: '#F59E0B',
        weight: 2,
        fillColor: '#F59E0B',
        fillOpacity: 0.12
      }).addTo(map);
      zoneBCircle.bindTooltip("Crane Lift Hazard Area B", { permanent: true, direction: "center", className: "osm-hazard-tooltip" });

      // 3. Zone C: Substation Enclosure
      const zoneCCircle = L.circle([13.7561, 100.5031], {
        radius: 30,
        color: '#00F0FF',
        weight: 2,
        fillColor: '#00F0FF',
        fillOpacity: 0.1
      }).addTo(map);
      zoneCCircle.bindTooltip("Substation B Enclosure", { permanent: false, direction: "bottom" });

      mapInstanceRef.current = map;
    }

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  // Handle Tile Theme Switcher
  useEffect(() => {
    if (mapInstanceRef.current && tileLayerRef.current) {
      mapInstanceRef.current.removeLayer(tileLayerRef.current);
      const newSource = tileSources[mapTheme];
      tileLayerRef.current = L.tileLayer(newSource.url, {
        attribution: newSource.attribution,
        maxZoom: 20,
        subdomains: 'abcd'
      }).addTo(mapInstanceRef.current);
    }
  }, [mapTheme]);

  // Update Worker GPS Markers on OpenStreetMap
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    // Existing marker ids
    const currentMarkerIds = new Set(Object.keys(markersRef.current));
    const newWorkerIds = new Set(workers.map(w => w.id));

    // Remove old markers
    currentMarkerIds.forEach(id => {
      if (!newWorkerIds.has(id)) {
        map.removeLayer(markersRef.current[id]);
        delete markersRef.current[id];
      }
    });

    // Add or update markers
    workers.forEach(w => {
      const lat = w.lat || 13.7563;
      const lng = w.lng || 100.5018;
      const isSelected = selectedWorker?.id === w.id;
      const isFall = w.posture === 'FALL_DETECTED';

      // Custom Marker HTML Template
      const markerHtml = `
        <div style="position: relative; display: flex; align-items: center; justify-content: center;">
          ${isFall ? `<div style="position: absolute; width: 36px; height: 36px; border-radius: 50%; background: rgba(239, 68, 68, 0.4); animation: osm-ping 1.5s cubic-bezier(0, 0, 0.2, 1) infinite;"></div>` : ''}
          <div style="
            width: ${isSelected ? '24px' : '18px'};
            height: ${isSelected ? '24px' : '18px'};
            border-radius: 50%;
            background: ${isFall ? '#EF4444' : isSelected ? '#FF5722' : '#10B981'};
            border: 2px solid #0F172A;
            box-shadow: 0 0 12px ${isFall ? 'rgba(239, 68, 68, 0.8)' : isSelected ? 'rgba(255, 87, 34, 0.8)' : 'rgba(16, 185, 129, 0.5)'};
            transition: all 0.3s ease;
          "></div>
          <div style="
            position: absolute;
            top: 22px;
            left: 50%;
            transform: translateX(-50%);
            white-space: nowrap;
            background: rgba(15, 23, 42, 0.9);
            color: #F8FAFC;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 10px;
            font-family: 'JetBrains Mono', monospace;
            border: 1px solid ${isFall ? '#EF4444' : isSelected ? '#FF5722' : '#334155'};
            pointer-events: none;
          ">
            ${w.name ? w.name.split(' ')[0] : 'Worker'} (${w.helmetId || 'HLX'})
          </div>
        </div>
      `;

      const customIcon = L.divIcon({
        className: 'osm-custom-marker',
        html: markerHtml,
        iconSize: [36, 36],
        iconAnchor: [18, 18]
      });

      // Popup Content Template
      const popupHtml = `
        <div style="font-family: 'Inter', sans-serif; color: #DAE2FD; background: #0F172A; padding: 10px; border-radius: 8px; width: 190px;">
          <div style="font-size: 11px; color: #FF5722; font-weight: 700; font-family: 'JetBrains Mono', monospace; margin-bottom: 4px;">
            ${w.helmetId || 'HELMET-UNIT'}
          </div>
          <div style="font-size: 13px; font-weight: 700; color: #FFF; margin-bottom: 2px;">${w.name}</div>
          <div style="font-size: 11px; color: #94A3B8; margin-bottom: 8px;">${w.role}</div>
          
          <div style="font-size: 11px; display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="color: #94A3B8;">Posture:</span>
            <span style="font-weight: 700; color: ${isFall ? '#EF4444' : '#10B981'};">${w.posture}</span>
          </div>
          <div style="font-size: 11px; display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="color: #94A3B8;">Battery:</span>
            <span style="font-weight: 600;">${w.battery}%</span>
          </div>
          <div style="font-size: 11px; display: flex; justify-content: space-between;">
            <span style="color: #94A3B8;">GPS Fix:</span>
            <span style="font-weight: 600; color: #00F0FF;">3D Lock</span>
          </div>
        </div>
      `;

      if (markersRef.current[w.id]) {
        // Update position & icon
        markersRef.current[w.id].setLatLng([lat, lng]);
        markersRef.current[w.id].setIcon(customIcon);
        markersRef.current[w.id].getPopup().setContent(popupHtml);
      } else {
        // Create new marker
        const marker = L.marker([lat, lng], { icon: customIcon }).addTo(map);
        marker.bindPopup(popupHtml, { className: 'osm-custom-popup', closeButton: false });
        marker.on('click', () => {
          onSelectWorker(w);
        });
        markersRef.current[w.id] = marker;
      }
    });
  }, [workers, selectedWorker]);

  // Pan to Selected Worker when changed
  useEffect(() => {
    if (selectedWorker && mapInstanceRef.current) {
      const lat = selectedWorker.lat || 13.7563;
      const lng = selectedWorker.lng || 100.5018;
      mapInstanceRef.current.panTo([lat, lng], { animate: true, duration: 0.8 });
    }
  }, [selectedWorker]);

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', minHeight: '440px', borderRadius: 'var(--radius-md)', overflow: 'hidden' }}>
      {/* CSS Keyframes for Ping Animation & Tooltip Custom Styles */}
      <style>{`
        @keyframes osm-ping {
          75%, 100% {
            transform: scale(2.2);
            opacity: 0;
          }
        }
        .osm-custom-popup .leaflet-popup-content-wrapper {
          background: #0F172A !important;
          border: 1px solid #334155 !important;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.6) !important;
          padding: 0 !important;
          border-radius: 8px !important;
        }
        .osm-custom-popup .leaflet-popup-tip {
          background: #0F172A !important;
        }
        .osm-zone-tooltip {
          background: rgba(15, 23, 42, 0.85) !important;
          border: 1px dashed #475569 !important;
          color: #94A3B8 !important;
          font-family: 'JetBrains Mono', monospace !important;
          font-size: 10px !important;
          box-shadow: none !important;
        }
        .osm-hazard-tooltip {
          background: rgba(245, 158, 11, 0.15) !important;
          border: 1px solid #F59E0B !important;
          color: #FCD34D !important;
          font-family: 'JetBrains Mono', monospace !important;
          font-size: 10px !important;
          box-shadow: none !important;
        }
      `}</style>

      {/* Leaflet OpenStreetMap Container */}
      <div ref={mapContainerRef} style={{ width: '100%', height: '100%', minHeight: '440px' }} />

      {/* Top Map Toolbar: OpenStreetMap Brand Badge & Theme Toggle */}
      <div
        style={{
          position: 'absolute',
          top: '12px',
          left: '12px',
          zIndex: 1000,
          display: 'flex',
          alignItems: 'center',
          gap: '0.6rem'
        }}
      >
        <div
          style={{
            background: 'rgba(15, 23, 42, 0.9)',
            backdropFilter: 'blur(6px)',
            border: '1px solid var(--border-subtle)',
            padding: '0.4rem 0.75rem',
            borderRadius: 'var(--radius-md)',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.4)'
          }}
        >
          <Compass size={16} color="var(--primary-orange)" />
          <span style={{ fontSize: '0.78rem', fontWeight: 600, fontFamily: 'var(--font-headline)', color: '#FFF' }}>
            OpenStreetMap <span style={{ color: 'var(--primary-orange)', fontWeight: 300 }}>GPS Layer</span>
          </span>
        </div>

        <button
          onClick={() => setMapTheme(mapTheme === 'dark' ? 'standard' : 'dark')}
          style={{
            background: 'rgba(15, 23, 42, 0.9)',
            backdropFilter: 'blur(6px)',
            border: '1px solid var(--border-subtle)',
            color: 'var(--text-main)',
            padding: '0.4rem 0.65rem',
            borderRadius: 'var(--radius-md)',
            fontSize: '0.75rem',
            fontWeight: 600,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: '0.4rem',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.4)'
          }}
        >
          <Layers size={14} color="var(--status-cyan)" />
          {mapTheme === 'dark' ? 'Dark OSM' : 'Standard OSM'}
        </button>
      </div>

      {/* Empty State Overlay if No Active Workers */}
      {workers.length === 0 && (
        <div
          style={{
            position: 'absolute',
            bottom: '20px',
            left: '50%',
            transform: 'translateX(-50%)',
            zIndex: 1000,
            background: 'rgba(15, 23, 42, 0.92)',
            border: '1px solid var(--border-highlight)',
            padding: '0.5rem 1rem',
            borderRadius: 'var(--radius-full)',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            fontSize: '0.78rem',
            color: 'var(--text-muted)',
            boxShadow: '0 10px 25px rgba(0, 0, 0, 0.5)',
            fontFamily: 'var(--font-mono)'
          }}
        >
          <Radio size={14} color="var(--status-amber)" className="animate-pulse" />
          OpenStreetMap Ready • Awaiting ESP32 GPS Lock
        </div>
      )}
    </div>
  );
}
