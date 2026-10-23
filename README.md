# certy

گرفتن SSL رایگان (Let's Encrypt) روی هاست سی‌پنل فقط با یک دستور — بر پایه‌ی `certbot`.

```bash
certy -d example.com --wildcard
```

- **بدون نیاز به root**: همه‌چیز در `~/bin` و `~/.certy` نصب می‌شود.
- **certbot آماده**: باینری مستقل certbot با GitHub Actions ساخته شده و در Releases قرار دارد (بدون نیاز به Python).
- **وریفای همیشه با DNS (DNS-01)**: رکوردهای TXT از طریق `uapi` سی‌پنل خودکار اضافه و بعد حذف می‌شوند و در یک جدول نمایش داده می‌شوند.
- **نصب خودکار روی سی‌پنل** و **تمدید خودکار** با cron.

## نصب

روی هاست سی‌پنل (Terminal یا SSH):

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/certy/main/install.sh | bash
```

اگر دسترسی root دارید و می‌خواهید certbot از پکیج‌منیجر سیستم‌عامل نصب شود:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/certy/main/install.sh | bash -s -- --root
```

(اگر هیچ‌کدام از `--root` / `--user` را ندهید، نصاب از شما می‌پرسد.)

## استفاده

```bash
# دامنه + وایلدکارد (*.example.com)
certy -d example.com --wildcard

# چند دامنه، بدون وایلدکارد
certy -d example.com -d www.example.com -d shop.example.com
certy -d example.com,www.example.com

# با ایمیل برای هشدار انقضا
certy -d example.com -e me@example.com

# DNS دست شما نیست (مثلاً Cloudflare): رکوردها را چاپ می‌کند و منتظر می‌ماند
certy -d example.com --wildcard --manual
```

خروجی نمونه:

```
┌───┬──────────────────────────────┬──────┬─────┬─────────────────────────────────────────────┬────────┐
│ # │ Name                         │ Type │ TTL │ Value                                       │ Status │
├───┼──────────────────────────────┼──────┼─────┼─────────────────────────────────────────────┼────────┤
│ 1 │ _acme-challenge.example.com  │ TXT  │ 60  │ uOp7TmC-K4q0b3MHPLYs8e_awkEMTDmr0D8-pVMuir4 │ added  │
│ 2 │ _acme-challenge.example.com  │ TXT  │ 60  │ i1Ny4Oqr3at3FcgHzkVsqi_d4GBhKsuWADs-zs4V2-o │ added  │
└───┴──────────────────────────────┴──────┴─────┴─────────────────────────────────────────────┴────────┘
```

| دستور | کار |
|---|---|
| `certy renew` | تمدید همه‌ی گواهی‌ها (cron روزانه خودکار اضافه می‌شود) |
| `certy list` | لیست گواهی‌ها |
| `certy cron` / `certy uninstall-cron` | افزودن / حذف cron تمدید |
| `certy update` | به‌روزرسانی certy و certbot |

| گزینه | توضیح |
|---|---|
| `-d, --domain` | دامنه (قابل تکرار یا با کاما) |
| `-w, --wildcard` | اضافه کردن `*.domain` برای هر دامنه |
| `-e, --email` | ایمیل حساب Let's Encrypt (ذخیره می‌شود) |
| `--manual` | بدون دست زدن به DNS؛ فقط جدول را نشان می‌دهد |
| `--no-install` | نصب نکردن گواهی روی سی‌پنل |
| `--staging` | سرور تست Let's Encrypt |
| `--force` | صدور مجدد حتی اگر گواهی معتبر است |

فایل‌ها: `~/.certy/config/live/<domain>/` (`fullchain.pem`, `privkey.pem`, …)

متغیر `CERTY_DNS_TIMEOUT` (پیش‌فرض ۳۰۰ ثانیه) حداکثر زمان انتظار برای انتشار DNS است.

## ساخت باینری certbot

ورک‌فلو [`.github/workflows/release.yml`](.github/workflows/release.yml) با هر تگ `v*` (یا اجرای دستی) certbot را با PyInstaller داخل کانتینر `manylinux2014` برای `x86_64` و `aarch64` می‌سازد (سازگار با CentOS 7 / CloudLinux و جدیدتر) و در Release آپلود می‌کند:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

اگر باینری روی سرور اجرا نشود، نصاب به‌صورت خودکار certbot را در یک virtualenv پایتون نصب می‌کند.

## License

MIT
