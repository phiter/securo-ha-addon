/**
 * Resolve the effective base path for assets, API calls, and the router.
 *
 * Priority:
 *  1. HA ingress URL pattern — detected directly from window.location.pathname
 *     so it works without any server-side injection.
 *  2. A runtime-injected <base href="..."> tag (set by nginx sub_filter).
 *  3. The Vite build-time BASE_URL (defaults to "/" or whatever VITE_BASE_PATH
 *     was set to at build time).
 */
export function getBasePath(): string {
  // Detect /api/hassio_ingress/<token>/ prefix injected by HA ingress.
  const ingressMatch = window.location.pathname.match(
    /^(\/api\/hassio_ingress\/[^/]+\/)/,
  )
  if (ingressMatch) {
    return ingressMatch[1]
  }

  const tag = document.querySelector<HTMLBaseElement>('base[href]')
  if (tag?.href) {
    const path = tag.href.replace(window.location.origin, '')
    return path.endsWith('/') ? path : `${path}/`
  }

  return import.meta.env.BASE_URL
}
