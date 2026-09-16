import { LightningElement, api } from 'lwc';

const IMAGE_EXTENSIONS = new Set([
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg'
]);

const INLINE_FRAME_EXTENSIONS = new Set([
    'pdf',
    'txt',
    'csv',
    'json',
    'xml'
]);

const RENDITION_EXTENSIONS = new Set([
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx'
]);

export default class LwcOrientSupportingDocumentPreview
    extends LightningElement {

    _documents = [];
    _selectedDocumentId;

    currentIndex = 0;
    currentPreviewUrl = '';
    currentOriginalUrl = '';
    isLoading = false;
    loadError = '';
    attemptedBlobFallback = false;

    activeObjectUrls = new Set();

    @api
    set documents(value) {
        this._documents =
            this.normalizeDocuments(value);

        this.syncSelectedDocument();
    }

    get documents() {
        return this._documents;
    }

    @api
    set selectedDocumentId(value) {
        this._selectedDocumentId = value;
        this.syncSelectedDocument();
    }

    get selectedDocumentId() {
        return this._selectedDocumentId;
    }

    disconnectedCallback() {
        this.releaseAllObjectUrls();
    }

    get hasDocuments() {
        return this._documents.length > 0;
    }

    get currentDocument() {
        return this.hasDocuments
            ? this._documents[this.currentIndex]
            : null;
    }

    get currentDocumentId() {
        return this.currentDocument?.contentDocumentId;
    }

    get currentVersionId() {
        return this.currentDocument?.latestVersionId;
    }

    get currentDisplayName() {
        return (
            this.currentDocument?.displayName ||
            'Supporting Document'
        );
    }

    get currentExtension() {
        return this.currentDocument?.fileExtension || '';
    }

    get currentExtensionLabel() {
        return this.currentExtension
            ? this.currentExtension.toUpperCase()
            : 'FILE';
    }

    get positionLabel() {
        if (!this.hasDocuments) {
            return '0 of 0';
        }

        return `${this.currentIndex + 1} of ${this._documents.length}`;
    }

    get previousDisabled() {
        return (
            this.currentIndex <= 0 ||
            this.isLoading
        );
    }

    get nextDisabled() {
        return (
            this.currentIndex >=
                this._documents.length - 1 ||
            this.isLoading
        );
    }

    get isImage() {
        return IMAGE_EXTENSIONS.has(
            this.currentExtension
        );
    }

    get isInlineFrame() {
        return INLINE_FRAME_EXTENSIONS.has(
            this.currentExtension
        );
    }

    get isRenditionFile() {
        return RENDITION_EXTENSIONS.has(
            this.currentExtension
        );
    }

    get showImage() {
        return (
            !this.isLoading &&
            !this.loadError &&
            this.isImage &&
            Boolean(this.currentPreviewUrl)
        );
    }

    get showInlineFrame() {
        return (
            !this.isLoading &&
            !this.loadError &&
            this.isInlineFrame &&
            Boolean(this.currentPreviewUrl)
        );
    }

    get showRendition() {
        return (
            !this.isLoading &&
            !this.loadError &&
            this.isRenditionFile &&
            Boolean(this.currentPreviewUrl)
        );
    }

    get showUnsupported() {
        return (
            !this.isLoading &&
            !this.loadError &&
            !this.showImage &&
            !this.showInlineFrame &&
            !this.showRendition
        );
    }

    get thumbnailDocuments() {
        return this._documents.map(
            (item, index) => ({
                ...item,
                index,
                position: index + 1,
                buttonClass:
                    index === this.currentIndex
                        ? 'document-tab document-tab-active'
                        : 'document-tab',
                iconName:
                    this.getIconName(
                        item.fileExtension
                    )
            })
        );
    }

    normalizeDocuments(value) {
        if (!Array.isArray(value)) {
            return [];
        }

        const seen = new Set();
        const result = [];

        value.forEach(item => {
            const contentDocumentId =
                item?.contentDocumentId ||
                item?.documentId;

            if (
                !contentDocumentId ||
                seen.has(contentDocumentId)
            ) {
                return;
            }

            seen.add(contentDocumentId);

            const displayName =
                item?.name ||
                this.buildDisplayName(item);

            result.push({
                ...item,
                contentDocumentId,
                latestVersionId:
                    item?.latestVersionId ||
                    item?.contentVersionId ||
                    null,
                displayName,
                fileExtension:
                    this.getExtension(
                        item?.fileExtension,
                        displayName
                    )
            });
        });

        return result;
    }

    buildDisplayName(item) {
        const title =
            item?.title ||
            'Supporting Document';

        const extension =
            String(
                item?.fileExtension || ''
            ).trim();

        if (
            extension &&
            !title.toLowerCase().endsWith(
                `.${extension.toLowerCase()}`
            )
        ) {
            return `${title}.${extension}`;
        }

        return title;
    }

    getExtension(
        explicitExtension,
        fileName
    ) {
        if (explicitExtension) {
            return String(
                explicitExtension
            )
                .replace(/^\./, '')
                .toLowerCase();
        }

        const name =
            String(fileName || '');

        const dotIndex =
            name.lastIndexOf('.');

        return dotIndex >= 0
            ? name.substring(
                dotIndex + 1
            ).toLowerCase()
            : '';
    }

    syncSelectedDocument() {
        if (!this.hasDocuments) {
            this.currentIndex = 0;
            this.resetCurrentPreview();
            return;
        }

        const requestedId =
            this._selectedDocumentId;

        const requestedIndex =
            requestedId
                ? this._documents.findIndex(
                    item =>
                        item.contentDocumentId ===
                        requestedId
                )
                : -1;

        this.currentIndex =
            requestedIndex >= 0
                ? requestedIndex
                : Math.min(
                    this.currentIndex,
                    this._documents.length - 1
                );

        this.loadCurrentDocument();
    }

    loadCurrentDocument() {
        this.resetCurrentPreview();

        const documentId =
            this.currentDocumentId;

        if (!documentId) {
            return;
        }

        this.attemptedBlobFallback = false;
        this.isLoading = false;

        this.currentOriginalUrl =
            this.buildDocumentDownloadUrl(
                documentId
            );

        if (this.isRenditionFile) {
            if (this.currentVersionId) {
                this.currentPreviewUrl =
                    this.buildRenditionUrl(
                        this.currentVersionId
                    );
            } else {
                this.currentPreviewUrl = '';
            }
            return;
        }

        /*
         * IMPORTANT:
         * Render the Salesforce file URL directly in the HTML element.
         * Do not fetch it first. Desktop Lightning can block/redirect the
         * fetch under CSP/CORS even though the same URL renders correctly
         * as an image/document resource.
         */
        this.currentPreviewUrl =
            this.currentOriginalUrl;
    }

    async handlePreviewError() {
        if (
            !this.isImage ||
            this.attemptedBlobFallback ||
            !this.currentOriginalUrl
        ) {
            this.loadError =
                'This file could not be rendered inside the custom preview.';
            return;
        }

        /*
         * Mobile WebView has already proven capable of fetching the file.
         * Keep one blob fallback for environments where direct image
         * rendering fails. Desktop normally succeeds on the direct path,
         * so it no longer enters the CSP-sensitive fetch path.
         */
        this.attemptedBlobFallback = true;
        this.isLoading = true;
        this.loadError = '';

        const documentId =
            this.currentDocumentId;

        try {
            const response =
                await fetch(
                    this.currentOriginalUrl,
                    {
                        method: 'GET',
                        credentials: 'same-origin',
                        cache: 'no-store'
                    }
                );

            if (!response.ok) {
                throw new Error(
                    `Unable to load this Salesforce File (${response.status}).`
                );
            }

            const blob =
                await response.blob();

            if (
                documentId !==
                this.currentDocumentId
            ) {
                return;
            }

            this.currentPreviewUrl =
                this.createObjectUrl(blob);
        } catch (error) {
            if (
                documentId ===
                this.currentDocumentId
            ) {
                this.loadError =
                    this.reduceError(error);
            }
        } finally {
            if (
                documentId ===
                this.currentDocumentId
            ) {
                this.isLoading = false;
            }
        }
    }

    buildDocumentDownloadUrl(
        documentId
    ) {
        return (
            '/sfc/servlet.shepherd/document/download/' +
            encodeURIComponent(
                documentId
            )
        );
    }

    buildRenditionUrl(
        versionId
    ) {
        return (
            '/sfc/servlet.shepherd/version/renditionDownload' +
            '?rendition=THUMB720BY480' +
            '&versionId=' +
            encodeURIComponent(
                versionId
            )
        );
    }

    createObjectUrl(blob) {
        const url =
            URL.createObjectURL(blob);

        this.activeObjectUrls.add(
            url
        );

        return url;
    }

    releaseAllObjectUrls() {
        this.activeObjectUrls.forEach(
            url => {
                try {
                    URL.revokeObjectURL(
                        url
                    );
                } catch (ignoreError) {
                    // Object URL was already released.
                }
            }
        );

        this.activeObjectUrls.clear();
    }

    resetCurrentPreview() {
        this.releaseAllObjectUrls();

        this.currentPreviewUrl = '';
        this.currentOriginalUrl = '';
        this.loadError = '';
        this.isLoading = false;
        this.attemptedBlobFallback = false;
    }

    handlePrevious() {
        if (this.previousDisabled) {
            return;
        }

        this.currentIndex--;
        this.loadCurrentDocument();
    }

    handleNext() {
        if (this.nextDisabled) {
            return;
        }

        this.currentIndex++;
        this.loadCurrentDocument();
    }

    handleDocumentTab(event) {
        const index =
            Number(
                event.currentTarget
                    ?.dataset?.index
            );

        if (
            Number.isNaN(index) ||
            index < 0 ||
            index >=
                this._documents.length ||
            index === this.currentIndex
        ) {
            return;
        }

        this.currentIndex = index;
        this.loadCurrentDocument();
    }

    handleClose() {
        this.releaseAllObjectUrls();

        this.dispatchEvent(
            new CustomEvent(
                'closepreview'
            )
        );
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this.handleClose();
            return;
        }

        if (event.key === 'ArrowLeft') {
            this.handlePrevious();
            return;
        }

        if (event.key === 'ArrowRight') {
            this.handleNext();
        }
    }

    getIconName(extension) {
        const value =
            String(extension || '')
                .toLowerCase();

        if (IMAGE_EXTENSIONS.has(value)) {
            return 'doctype:image';
        }

        if (value === 'pdf') {
            return 'doctype:pdf';
        }

        if (
            value === 'doc' ||
            value === 'docx'
        ) {
            return 'doctype:word';
        }

        if (
            value === 'xls' ||
            value === 'xlsx' ||
            value === 'csv'
        ) {
            return 'doctype:excel';
        }

        if (
            value === 'ppt' ||
            value === 'pptx'
        ) {
            return 'doctype:ppt';
        }

        if (
            value === 'txt' ||
            value === 'json' ||
            value === 'xml'
        ) {
            return 'doctype:txt';
        }

        return 'doctype:attachment';
    }

    reduceError(error) {
        return (
            error?.body?.message ||
            error?.message ||
            'The supporting document could not be loaded.'
        );
    }
}