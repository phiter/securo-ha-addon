/**
 * Resolve the effective base path from a runtime-injected <base> tag (set by
 * reverse proxies such as Home Assistant ingress) or fall back to the
 * build-time Vite BASE_URL.
 *
 * Usage: set `<base href="/my/prefix/">` in index.html at request time (e.g.
 * via nginx sub_filter) and every API call / router link will follow it
 * automatically without a rebuild.
 */
export function getBasePath(): string {
  const tag = document.querySelector<HTMLBaseElement>('base[href]')
  if (tag?.href) {
    // Convert the absolute href back to a pathname, always trailing-slash.
    const path = tag.href.replace(window.location.origin, '')
    return path.endsWith('/') ? path : `${path}/`
  }
  return import.meta.env.BASE_URL
}
