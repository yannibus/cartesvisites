import { LightningElement, api } from 'lwc';
import CV_Drop_Title from '@salesforce/label/c.CV_Drop_Title';
import CV_Drop_Hint from '@salesforce/label/c.CV_Drop_Hint';

export default class CvDropZone extends LightningElement {
    @api titleLabel;
    @api hintLabel;

    label = {
        defaultTitle: CV_Drop_Title,
        defaultHint: CV_Drop_Hint
    };

    isDragging = false;

    get effectiveTitle() {
        return this.titleLabel || this.label.defaultTitle;
    }

    get effectiveHint() {
        return this.hintLabel || this.label.defaultHint;
    }

    get zoneClass() {
        return this.isDragging
            ? 'cv-dropzone cv-dropzone--active'
            : 'cv-dropzone';
    }

    handleDragEnter(event) {
        event.preventDefault();
        this.isDragging = true;
    }

    handleDragOver(event) {
        event.preventDefault();
        this.isDragging = true;
    }

    handleDragLeave(event) {
        event.preventDefault();
        this.isDragging = false;
    }

    handleDrop(event) {
        event.preventDefault();
        this.isDragging = false;
        const files = Array.from(event.dataTransfer.files || []).filter(f =>
            f.type.startsWith('image/')
        );
        if (files.length) this.emit(files);
    }

    handleClick() {
        this.refs.fileInput.click();
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleClick();
        }
    }

    handleFileChange(event) {
        const files = Array.from(event.target.files || []);
        if (files.length) this.emit(files);
        event.target.value = null;
    }

    emit(files) {
        this.dispatchEvent(
            new CustomEvent('filesselected', { detail: { files } })
        );
    }
}
