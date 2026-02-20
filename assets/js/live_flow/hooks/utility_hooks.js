/**
 * LiveFlow Utility Hooks
 *
 * Small hooks for file import/export, download triggers, etc.
 */

/**
 * FileImport hook — reads a selected file and sends its content to the server.
 * Attach to an <input type="file"> element.
 */
export const FileImportHook = {
  mounted() {
    this.el.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (event) => {
        this.pushEvent('import_json', { content: event.target.result });
        // Reset the input so the same file can be re-imported
        this.el.value = '';
      };
      reader.readAsText(file);
    });
  }
};

/**
 * Triggers a file download from a push_event.
 * Listens for "lf:download_file" events with {content, filename, type}.
 * Uses data URI for text content (more reliable across browsers).
 */
export function setupDownloadHandler(liveSocket) {
  window.addEventListener('phx:lf:download_file', (event) => {
    const { content, filename, type } = event.detail;
    const a = document.createElement('a');
    a.href = 'data:' + (type || 'application/octet-stream') + ';charset=utf-8,' + encodeURIComponent(content);
    a.download = filename || 'download';
    a.style.position = 'fixed';
    a.style.left = '-9999px';
    a.style.top = '-9999px';
    a.style.opacity = '0';
    document.body.appendChild(a);
    a.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
    setTimeout(() => {
      document.body.removeChild(a);
    }, 10000);
  });
}
