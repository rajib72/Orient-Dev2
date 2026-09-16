import { LightningElement, api } from 'lwc';
import brandLogoResource from '@salesforce/resourceUrl/brandLogo2';

/**
 * The shell every screen in the feedback journey sits in: the cream-and-gold
 * ground with its double frame, the centred logo header with optional
 * navigation, and the maroon base band. The screen supplies its own body
 * through the default slot.
 */
export default class FdbScreen extends LightningElement {
    /** Text for the left-hand button. Omit it and no button is rendered. */
    @api navLabel = '';

    /** 'home' swaps the chevron for a house. Anything else keeps the chevron. */
    @api navIcon = 'back';

    /**
     * 'fit' pins the shell to exactly the height available, for the two screens
     * laid out to fill it. 'inline' is for a screen opened inside something
     * else - a quick action dialog - where the height available is not ours to
     * take and the container does the scrolling. Anything else lets the shell
     * grow with its content and the page scroll, which is how every other
     * screen behaves.
     */
    @api layout = '';

    /**
     * 'none' drops the engraved rule that closes the header. The welcome screen
     * asks for that: it already opens on its own ornament a few lines down, and
     * two gold rules that close to each other read as a printing fault.
     */
    @api headRule = '';

    brandLogoUrl = brandLogoResource;

    get shellClass() {
        const classes = ['ojp'];
        if (this.layout === 'fit') classes.push('ojp_fit');
        if (this.layout === 'inline') classes.push('ojp_inline');
        if (this.headRule === 'none') classes.push('ojp_norule');
        return classes.join(' ');
    }

    // ---- AVAILABLE HEIGHT ----
    /**
     * How much room we actually have. Screens that fill the screen are sized to
     * it exactly; the rest use it as a floor and grow past it.
     *
     * 100vh cannot express either. This runs on a Lightning tab, so Salesforce
     * chrome sits above us and a navigation bar below, and 100vh counts both as
     * ours - which is what put the foot of every page behind the nav bar. Only
     * the browser knows where our edges land, so the height is measured rather
     * than declared, and published as --oj-vh for the CSS.
     */
    resizeHandler;

    connectedCallback() {
        this.resizeHandler = () => this.scheduleMeasure();
        window.addEventListener('resize', this.resizeHandler);
        window.addEventListener('orientationchange', this.resizeHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.resizeHandler);
        window.removeEventListener('orientationchange', this.resizeHandler);
    }

    renderedCallback() {
        this.scheduleMeasure();
    }

    scheduleMeasure() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => this.measure());
        // Android reports the old viewport for a beat after a rotation, so take
        // a second reading once the browser has settled.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.measure(), 250);
    }

    /**
     * Walks up to the first ancestor that actually clips us, crossing shadow
     * boundaries on the way.
     *
     * The viewport is not the answer. In the Salesforce mobile app a fixed
     * navigation bar sits across the bottom of the screen, so the region we are
     * given ends well above the bottom of the viewport - measuring to the
     * viewport makes us taller than our container by the height of that bar,
     * and the foot of every page disappears behind it.
     */
    clippingAncestor(el) {
        let node = el.parentNode;
        while (node) {
            if (node.host) {
                node = node.host;
                continue;
            }
            if (node.nodeType === 1) {
                const overflowY = window.getComputedStyle(node).overflowY;
                const clips = overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'hidden';
                if (clips && node.clientHeight > 0) return node;
            }
            node = node.parentNode;
        }
        return null;
    }

    measure() {
        // Embedded in a dialog the height available is not ours to take - the
        // container sizes us, and measuring would only fight it.
        if (this.layout === 'inline') return;

        const shell = this.template.querySelector('.ojp');
        if (!shell) return;

        const top = shell.getBoundingClientRect().top;
        const viewport = (window.visualViewport && window.visualViewport.height) || window.innerHeight;

        // Whichever runs out first - our container or the screen itself
        let bottom = viewport;
        const clipper = this.clippingAncestor(shell);
        if (clipper) {
            bottom = Math.min(bottom, clipper.getBoundingClientRect().bottom);
        }

        // A floor keeps the layout sane if we are measured while hidden or
        // mid-transition, when the rect can come back as nonsense.
        const available = Math.max(360, Math.round(bottom - top));

        shell.style.setProperty('--oj-vh', available + 'px');

        // Below this the decorative parts have to go or something gets pushed
        // off screen. The CSS cannot work this out for itself - a height media
        // query sees the browser viewport, not the box we were actually given.
        shell.classList.toggle('ojp_short', available < 520);
    }

    get showNav() {
        return !!this.navLabel;
    }

    get isHomeIcon() {
        return this.navIcon === 'home';
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('navclick'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('helpclick'));
    }
}