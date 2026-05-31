<div wire:ignore
    style="background: #eff6ff; border: 1px solid #3b82f6; padding: 10px; margin-top: 20px; text-align: center; font-weight: bold; border-radius: 8px; color: #1e3a8a; position: relative;"
    x-data="{
        barcode: '',
        timeout: null,
        loading: false,
        playBeep() {
            try {
                const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                if (audioCtx.state === 'suspended') {
                    audioCtx.resume();
                }
                const oscillator = audioCtx.createOscillator();
                const gainNode = audioCtx.createGain();
                oscillator.connect(gainNode);
                gainNode.connect(audioCtx.destination);
                oscillator.type = 'sine';
                oscillator.frequency.setValueAtTime(880, audioCtx.currentTime);
                gainNode.gain.setValueAtTime(0.3, audioCtx.currentTime);
                oscillator.start();
                oscillator.stop(audioCtx.currentTime + 0.15);
            } catch (err) {
                console.log('Beep sound not supported or blocked by browser policy', err);
            }
        },
        async sendBarcode(code) {
            this.loading = true;
            this.playBeep();
            try {
                await $wire.processScannedBarcode(code);
            } finally {
                this.loading = false;
            }
        },
        init() {
            console.log('🚀 Barcode Listener Initialized (Optimized)');
            
            window.addEventListener('paste', (e) => {
                if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
                
                let pastedData = (e.clipboardData || window.clipboardData).getData('text');
                if (pastedData && pastedData.trim().length > 3) {
                    console.log('📦 PASTED barcode:', pastedData.trim());
                    this.sendBarcode(pastedData.trim());
                }
            });

            window.addEventListener('keydown', (e) => {
                if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
                
                if (e.key === 'Enter') {
                    if (this.barcode.length > 3) {
                        console.log('📦 TYPED barcode:', this.barcode);
                        this.sendBarcode(this.barcode);
                    }
                    this.barcode = '';
                    return;
                }
                
                if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
                    this.barcode += e.key;
                    clearTimeout(this.timeout);
                    this.timeout = setTimeout(() => { this.barcode = ''; }, 1000);
                }
            });
        }
    }"
>
    <template x-if="loading">
        <div style="display: flex; align-items: center; justify-content: center; gap: 8px;">
            <svg class="animate-spin" style="width: 20px; height: 20px; color: #3b82f6;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle style="opacity: 0.25;" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path style="opacity: 0.75;" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
            </svg>
            <span>جاري البحث عن المنتج...</span>
        </div>
    </template>
    <template x-if="!loading">
        <span>🔵 نظام مسح الباركود مفعل - امسح أو الصق الباركود</span>
    </template>
</div>
