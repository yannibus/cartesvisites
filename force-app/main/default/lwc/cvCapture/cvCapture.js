import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadCard from '@salesforce/apex/CV_CardProcessor.uploadCard';
import processCard from '@salesforce/apex/CV_CardProcessor.processCard';
import createLead from '@salesforce/apex/CV_CardProcessor.createLead';
import linkCardToLead from '@salesforce/apex/CV_CardProcessor.linkCardToLead';

import CV_Title from '@salesforce/label/c.CV_Title';
import CV_Subtitle from '@salesforce/label/c.CV_Subtitle';
import CV_CounterReadyOf from '@salesforce/label/c.CV_CounterReadyOf';
import CV_AddMore from '@salesforce/label/c.CV_AddMore';
import CV_ClearAll from '@salesforce/label/c.CV_ClearAll';
import CV_CreateLeads from '@salesforce/label/c.CV_CreateLeads';
import CV_CreateLead_Singular from '@salesforce/label/c.CV_CreateLead_Singular';
import CV_CreateLeads_PluralPrefix from '@salesforce/label/c.CV_CreateLeads_PluralPrefix';
import CV_CreateLeads_PluralSuffix from '@salesforce/label/c.CV_CreateLeads_PluralSuffix';
import CV_Analyzing from '@salesforce/label/c.CV_Analyzing';
import CV_ProcessingAlt from '@salesforce/label/c.CV_ProcessingAlt';
import CV_ReadyInfo_Singular from '@salesforce/label/c.CV_ReadyInfo_Singular';
import CV_ReadyInfo_PluralSuffix from '@salesforce/label/c.CV_ReadyInfo_PluralSuffix';
import CV_Toast_SuccessTitle from '@salesforce/label/c.CV_Toast_SuccessTitle';
import CV_Toast_ErrorTitle from '@salesforce/label/c.CV_Toast_ErrorTitle';
import CV_Toast_LeadCreatedSingular from '@salesforce/label/c.CV_Toast_LeadCreatedSingular';
import CV_Toast_LeadCreatedPluralSuffix from '@salesforce/label/c.CV_Toast_LeadCreatedPluralSuffix';
import CV_Error_AnalysisFailed from '@salesforce/label/c.CV_Error_AnalysisFailed';
import CV_Toast_DuplicateSuffix from '@salesforce/label/c.CV_Toast_DuplicateSuffix';

const STATUS = {
    UPLOADING: 'uploading',
    PROCESSING: 'processing',
    READY: 'ready',
    ERROR: 'error',
    CREATED: 'created',
    DUPLICATE: 'duplicate'
};

let cardSeq = 0;

export default class CvCapture extends LightningElement {
    @track cards = [];

    label = {
        title: CV_Title,
        subtitle: CV_Subtitle,
        counterReadyOf: CV_CounterReadyOf,
        addMore: CV_AddMore,
        clearAll: CV_ClearAll,
        analyzing: CV_Analyzing,
        processingAlt: CV_ProcessingAlt
    };

    get hasCards() {
        return this.cards.length > 0;
    }

    get noCards() {
        return this.cards.length === 0;
    }

    get totalCount() {
        return this.cards.length;
    }

    get readyCount() {
        return this.cards.filter(c => c.status === STATUS.READY).length;
    }

    get processingCount() {
        return this.cards.filter(
            c => c.status === STATUS.UPLOADING || c.status === STATUS.PROCESSING
        ).length;
    }

    get readyInfoText() {
        return this.readyCount > 1
            ? `${this.readyCount} ${CV_ReadyInfo_PluralSuffix}`
            : CV_ReadyInfo_Singular;
    }

    get cannotCreate() {
        return this.readyCount === 0;
    }

    get createButtonLabel() {
        if (this.readyCount === 0) return CV_CreateLeads;
        if (this.readyCount === 1) return CV_CreateLead_Singular;
        return `${CV_CreateLeads_PluralPrefix} ${this.readyCount} ${CV_CreateLeads_PluralSuffix}`.trim();
    }

    handleAddMore() {
        this.refs.hiddenInput.click();
    }

    handleHiddenInputChange(event) {
        const files = Array.from(event.target.files || []);
        if (files.length) this.ingestFiles(files);
        event.target.value = null;
    }

    handleFilesSelected(event) {
        this.ingestFiles(event.detail.files);
    }

    async ingestFiles(files) {
        const newCards = files.map(file => ({
            id: `card-${++cardSeq}`,
            file,
            title: file.name,
            contentDocumentId: null,
            status: STATUS.UPLOADING,
            firstName: null,
            lastName: null,
            company: null,
            email: null,
            mobile: null,
            phone: null,
            errorMessage: null,
            leadId: null
        }));
        this.cards = [...this.cards, ...newCards];

        for (const card of newCards) {
            this.uploadAndProcess(card.id, card.file);
        }
    }

    async uploadAndProcess(cardId, file) {
        try {
            const contentDocumentId = await this.uploadFile(file);
            this.patchCard(cardId, {
                contentDocumentId,
                status: STATUS.PROCESSING
            });
            const result = await processCard({ contentDocumentId });
            this.patchCard(cardId, this.resultToPatch(result));
        } catch (error) {
            this.patchCard(cardId, {
                status: STATUS.ERROR,
                errorMessage: this.extractError(error)
            });
        }
    }

    resultToPatch(result) {
        if (!result || result.status === 'error') {
            return {
                status: STATUS.ERROR,
                errorMessage: result?.errorMessage || CV_Error_AnalysisFailed
            };
        }
        return {
            status: STATUS.READY,
            firstName: result.firstName,
            lastName: result.lastName,
            company: result.company,
            email: result.email,
            mobile: result.mobile,
            phone: result.phone,
            title: result.title
        };
    }

    uploadFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                uploadCard({ fileName: file.name, base64Data: base64 })
                    .then(resolve)
                    .catch(reject);
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    handleFieldChange(event) {
        const { id, field, value } = event.detail;
        this.patchCard(id, { [field]: value });
    }

    handleRemove(event) {
        const { id } = event.detail;
        this.cards = this.cards.filter(c => c.id !== id);
    }

    handleRetry(event) {
        const { id } = event.detail;
        const card = this.cards.find(c => c.id === id);
        if (!card) return;
        this.patchCard(id, { status: STATUS.PROCESSING, errorMessage: null });
        if (card.contentDocumentId) {
            processCard({ contentDocumentId: card.contentDocumentId })
                .then(res => this.patchCard(id, this.resultToPatch(res)))
                .catch(err =>
                    this.patchCard(id, {
                        status: STATUS.ERROR,
                        errorMessage: this.extractError(err)
                    })
                );
        } else if (card.file) {
            this.uploadAndProcess(id, card.file);
        }
    }

    handleClearAll() {
        this.cards = [];
    }

    async handleCreateAll() {
        const readyCards = this.cards.filter(c => c.status === STATUS.READY);
        if (!readyCards.length) return;

        const patches = new Map();
        const errors = [];
        let createdCount = 0;
        let duplicateCount = 0;

        for (const c of readyCards) {
            try {
                const result = await createLead({
                    firstName: c.firstName,
                    lastName: c.lastName,
                    company: c.company,
                    email: c.email,
                    mobile: c.mobile,
                    phone: c.phone,
                    leadSource: 'Business Card'
                });

                if (result.status === 'duplicate') {
                    duplicateCount++;
                    patches.set(c.id, {
                        status: STATUS.DUPLICATE,
                        leadId: result.leadId,
                        duplicateLeadId: result.duplicateLeadId
                    });
                    // A new record was still saved (allowSave) → keep the photo linked.
                    if (result.leadId && c.contentDocumentId) {
                        linkCardToLead({ contentDocumentId: c.contentDocumentId, leadId: result.leadId })
                            .catch(err => console.error('linkCardToLead failed', err));
                    }
                } else if (result.status === 'created') {
                    createdCount++;
                    patches.set(c.id, { status: STATUS.CREATED, leadId: result.leadId });
                    if (c.contentDocumentId) {
                        linkCardToLead({ contentDocumentId: c.contentDocumentId, leadId: result.leadId })
                            .catch(err => console.error('linkCardToLead failed', err));
                    }
                } else {
                    errors.push(result.errorMessage || CV_Error_AnalysisFailed);
                }
            } catch (error) {
                errors.push(this.extractError(error));
            }
        }

        if (patches.size) {
            this.cards = this.cards.map(c =>
                patches.has(c.id) ? { ...c, ...patches.get(c.id) } : c
            );
        }

        const successMsgs = [];
        if (createdCount) {
            successMsgs.push(
                createdCount > 1
                    ? `${createdCount} ${CV_Toast_LeadCreatedPluralSuffix}`
                    : CV_Toast_LeadCreatedSingular
            );
        }
        if (duplicateCount) {
            successMsgs.push(`${duplicateCount} ${CV_Toast_DuplicateSuffix}`);
        }
        if (successMsgs.length) {
            this.toast(CV_Toast_SuccessTitle, successMsgs.join(' • '), 'success');
        }
        if (errors.length) {
            this.toast(CV_Toast_ErrorTitle, errors.join(' | '), 'error');
        }
    }

    patchCard(id, patch) {
        this.cards = this.cards.map(c =>
            c.id === id ? { ...c, ...patch } : c
        );
    }

    extractError(err) {
        return err?.body?.message || err?.message || String(err);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
