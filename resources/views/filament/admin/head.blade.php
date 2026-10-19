{{-- Muntajat shell: display face + Latin companion, and the table-density store. --}}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Kufi+Arabic:wght@600;700&family=Noto+Sans:wght@400;500;600;700&display=swap">
<script>
    (function () {
        var d = 'comfortable';
        try { d = localStorage.getItem('mt-density') || d } catch (e) {}
        document.documentElement.dataset.mtDensity = d;
    })();
    document.addEventListener('alpine:init', function () {
        Alpine.store('mtDensity', {
            v: document.documentElement.dataset.mtDensity || 'comfortable',
            set: function (v) {
                this.v = v;
                document.documentElement.dataset.mtDensity = v;
                try { localStorage.setItem('mt-density', v) } catch (e) {}
            },
        });
    });
</script>
