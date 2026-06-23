import { LightningElement, api } from 'lwc';
import CV_Card_Remove from '@salesforce/label/c.CV_Card_Remove';
import CV_Card_RemoveTooltip from '@salesforce/label/c.CV_Card_RemoveTooltip';
import CV_Card_Retry from '@salesforce/label/c.CV_Card_Retry';
import CV_Card_FirstName from '@salesforce/label/c.CV_Card_FirstName';
import CV_Card_LastName from '@salesforce/label/c.CV_Card_LastName';
import CV_Card_Company from '@salesforce/label/c.CV_Card_Company';
import CV_Card_Email from '@salesforce/label/c.CV_Card_Email';
import CV_Card_Mobile from '@salesforce/label/c.CV_Card_Mobile';
import CV_Card_Phone from '@salesforce/label/c.CV_Card_Phone';
import CV_Card_SeeLead from '@salesforce/label/c.CV_Card_SeeLead';
import CV_Card_SeeExisting from '@salesforce/label/c.CV_Card_SeeExisting';
import CV_Card_DuplicateInfo from '@salesforce/label/c.CV_Card_DuplicateInfo';
import CV_Status_Uploading from '@salesforce/label/c.CV_Status_Uploading';
import CV_Status_Processing from '@salesforce/label/c.CV_Status_Processing';
import CV_Status_Ready from '@salesforce/label/c.CV_Status_Ready';
import CV_Status_Error from '@salesforce/label/c.CV_Status_Error';
import CV_Status_Created from '@salesforce/label/c.CV_Status_Created';
import CV_Status_Duplicate from '@salesforce/label/c.CV_Status_Duplicate';
import CV_Status_Idle from '@salesforce/label/c.CV_Status_Idle';

const STATUS_UPLOADING = 'uploading';
const STATUS_PROCESSING = 'processing';
const STATUS_READY = 'ready';
const STATUS_ERROR = 'error';
const STATUS_CREATED = 'created';
const STATUS_DUPLICATE = 'duplicate';

export default class CvLeadCard extends LightningElement {
    @api card;

    label = {
        remove: CV_Card_Remove,
        removeTooltip: CV_Card_RemoveTooltip,
        retry: CV_Card_Retry,
        firstName: CV_Card_FirstName,
        lastName: CV_Card_LastName,
        company: CV_Card_Company,
        email: CV_Card_Email,
        mobile: CV_Card_Mobile,
        phone: CV_Card_Phone,
        seeLead: CV_Card_SeeLead,
        seeExisting: CV_Card_SeeExisting,
        duplicateInfo: CV_Card_DuplicateInfo
    };

    get cardClass() {
        return `cv-card cv-card--${this.card?.status || 'idle'}`;
    }

    get badgeClass() {
        const map = {
            [STATUS_UPLOADING]: 'slds-theme_default',
            [STATUS_PROCESSING]: 'slds-theme_info',
            [STATUS_READY]: 'slds-theme_success',
            [STATUS_ERROR]: 'slds-theme_error',
            [STATUS_CREATED]: 'slds-theme_success',
            [STATUS_DUPLICATE]: 'slds-theme_warning'
        };
        return `cv-card__badge ${map[this.card?.status] || ''}`;
    }

    get statusLabel() {
        const labels = {
            [STATUS_UPLOADING]: CV_Status_Uploading,
            [STATUS_PROCESSING]: CV_Status_Processing,
            [STATUS_READY]: CV_Status_Ready,
            [STATUS_ERROR]: CV_Status_Error,
            [STATUS_CREATED]: CV_Status_Created,
            [STATUS_DUPLICATE]: CV_Status_Duplicate
        };
        return labels[this.card?.status] || CV_Status_Idle;
    }

    get previewUrl() {
        if (!this.card?.contentDocumentId) return null;
        return `/sfc/servlet.shepherd/document/download/${this.card.contentDocumentId}?operationContext=CHATTER`;
    }

    get isProcessing() {
        return [STATUS_UPLOADING, STATUS_PROCESSING].includes(this.card?.status);
    }

    get isError() {
        return this.card?.status === STATUS_ERROR;
    }

    get isEditable() {
        return this.card?.status === STATUS_READY;
    }

    get isCreated() {
        return this.card?.status === STATUS_CREATED;
    }

    get isDuplicate() {
        return this.card?.status === STATUS_DUPLICATE;
    }

    get leadUrl() {
        return this.card?.leadId ? `/lightning/r/Lead/${this.card.leadId}/view` : '#';
    }

    get duplicateLeadUrl() {
        return this.card?.duplicateLeadId
            ? `/lightning/r/Lead/${this.card.duplicateLeadId}/view`
            : '#';
    }

    get createdLeadLabel() {
        const first = this.card?.firstName || '';
        const last = this.card?.lastName || '';
        return `${this.label.seeLead} ${first} ${last}`.trim();
    }

    get duplicateLeadLabel() {
        const first = this.card?.firstName || '';
        const last = this.card?.lastName || '';
        return `${this.label.seeExisting} ${first} ${last}`.trim();
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.dispatchEvent(
            new CustomEvent('fieldchange', {
                detail: { id: this.card.id, field, value }
            })
        );
    }

    handleRemove() {
        this.dispatchEvent(
            new CustomEvent('remove', { detail: { id: this.card.id } })
        );
    }

    handleRetry() {
        this.dispatchEvent(
            new CustomEvent('retry', { detail: { id: this.card.id } })
        );
    }
}
