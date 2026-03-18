<div wire:ignore
    style="background: #eff6ff; border: 1px solid #3b82f6; padding: 10px; margin-top: 20px; text-align: center; font-weight: bold; border-radius: 8px; color: #1e3a8a;"
    x-data="{
        barcode: '',
        timeout: null,
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
                oscillator.frequency.setValueAtTime(880, audioCtx.currentTime); // 880Hz = A5
                gainNode.gain.setValueAtTime(0.3, audioCtx.currentTime); // Volume
                oscillator.start();
                oscillator.stop(audioCtx.currentTime + 0.15); // 0.15 seconds
            } catch (err) {
                console.log('Beep sound not supported or blocked by browser policy', err);
            }
        },
        init() {
            console.log('🚀 Barcode Listener Initialized (With $wire Direct Call & Sound)');
            
            window.addEventListener('paste', (e) => {
                if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
                
                let pastedData = (e.clipboardData || window.clipboardData).getData('text');
                if (pastedData && pastedData.trim().length > 3) {
                    console.log('📦 PASTED barcode directly to $wire:', pastedData.trim());
                    this.playBeep();
                    $wire.processScannedBarcode(pastedData.trim());
                }
            });

            window.addEventListener('keydown', (e) => {
                if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
                
                if (e.key === 'Enter') {
                    if (this.barcode.length > 3) {
                        console.log('📦 TYPED barcode directly to $wire:', this.barcode);
                        this.playBeep();
                        $wire.processScannedBarcode(this.barcode);
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
    🔵 تحديث أخير للتأكد: نظام الالتقاط المباشر (مع الصوت) مفعل الآن خارج المربعات النصية!
</div>
