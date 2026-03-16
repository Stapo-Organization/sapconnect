<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ config('app.name') }} Notification</title>
    <style>
        /* Base Resets */
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif, 'Arial Arabic';
            line-height: 1.6;
            background-color: #f4f6f9;
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
        }
        table { border-collapse: collapse; width: 100%; }
        
        /* Container */
        .wrapper {
            width: 100%;
            background-color: #f4f6f9;
            padding: 40px 0;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 8px 16px rgba(0,0,0,0.05);
            border: 1px solid #e1e5eb;
        }

        /* Header Area */
        .header {
            background-color: #ffffff;
            padding: 30px;
            text-align: center;
            border-bottom: 3px solid #fec02f; /* Muntajat Yellow */
        }
        .header img {
            max-width: 220px;
            height: auto;
        }

        /* Content Area */
        .content {
            padding: 40px 30px;
            color: #333333;
        }

        /* Language Sections */
        .lang-section {
            margin-bottom: 25px;
        }
        .lang-section:last-child {
            margin-bottom: 0;
            padding-bottom: 0;
            border-bottom: none;
        }
        .lang-section.has-border {
            padding-bottom: 25px;
            border-bottom: 1px dashed #e1e5eb;
        }

        .arabic-section {
            direction: rtl;
            text-align: right;
            font-size: 16px;
        }
        .english-section {
            direction: ltr;
            text-align: left;
            font-size: 15px;
            color: #444444;
        }

        /* Typography & Details inside Body */
        h1, h2, h3 { color: #2B3A42; margin-top: 0; font-weight: 600; }
        p { margin: 0 0 15px 0; }
        
        /* Data Highlights */
        strong, b { color: #fec02f; }
        .highlight-box {
            background-color: #fcf9f2;
            border-right: 4px solid #fec02f;
            padding: 15px;
            margin: 20px 0;
            border-radius: 0 4px 4px 0;
        }
        .english-section .highlight-box {
            border-right: none;
            border-left: 4px solid #fec02f;
            border-radius: 4px 0 0 4px;
        }

        /* Action Buttons */
        .button-container {
            text-align: center;
            margin-top: 30px;
        }
        a.button {
            display: inline-block;
            padding: 12px 28px;
            text-decoration: none;
            border-radius: 6px;
            font-weight: bold;
            text-align: center;
            transition: background 0.3s ease;
            color: #ffffff !important;
        }
        .button-ar {
            background-color: #fec02f; /* Muntajat Primary Yellow */
            box-shadow: 0 4px 6px rgba(254, 192, 47, 0.3);
        }
        .button-en {
            background-color: #2B3A42; /* Muntajat Dark Blue/Grey */
            box-shadow: 0 4px 6px rgba(43, 58, 66, 0.2);
        }

        /* Footer Area */
        .footer {
            background: #f9fafc;
            text-align: center;
            padding: 24px;
            font-size: 13px;
            color: #888888;
            border-top: 1px solid #eeeeee;
        }
        .footer p { margin: 5px 0; }
        .help-link { color: #fec02f; text-decoration: none; font-weight: 500;}

        /* Responsive */
        @media only screen and (max-width: 600px) {
            .container { border-radius: 0; width: 100% !important; }
            .content { padding: 30px 20px; }
        }
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="container">
            
            <!-- Header with Muntajat Logo -->
            <div class="header">
                {{-- Use the image URL provided by the user. If unavailable locally, fallback to a CDN link. --}}
                <img src="https://muntajat.sa/wp-content/uploads/2024/02/105_73_MUNTJAT_logo.png" alt="Muntajat Company منتجات">
            </div>
            
            <!-- Dynamic Content -->
            <div class="content">
                @if(!empty($bodyAr))
                <div class="lang-section arabic-section {{ !empty($bodyEn) ? 'has-border' : '' }}">
                    {!! $bodyAr !!}
                </div>
                @endif

                @if(!empty($bodyEn))
                <div class="lang-section english-section">
                    {!! $bodyEn !!}
                </div>
                @endif
            </div>

            <!-- Footer -->
            <div class="footer">
                <p>&copy; {{ date('Y') }} شركة منتجات للصناعة المحدودة (Muntajat). جميع الحقوق محفوظة.</p>
                <p>هذه رسالة تلقائية من بوابة نظام <a href="https://sapapi.muntajat.sa" class="help-link">Muntajat Connect</a>، يرجى عدم الرد عليها.</p>
                <p dir="ltr" style="margin-top: 10px; font-size: 11px;">This is an automated system message, please do not reply.</p>
            </div>

        </div>
    </div>
</body>
</html>
