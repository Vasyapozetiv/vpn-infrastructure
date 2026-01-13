#!/usr/bin/env python3
"""
Simple VPN Telegram Bot
"""

import os
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
import subprocess

# Настройка логов
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Конфигурация
BOT_TOKEN = os.getenv('BOT_TOKEN', 'ВАШ_ТОКЕН_ЗДЕСЬ')
ADMIN_ID = int(os.getenv('ADMIN_ID', 'ВАШ_ID_ЗДЕСЬ'))

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик /start"""
    user = update.effective_user
    
    if user.id != ADMIN_ID:
        await update.message.reply_text("⛔ Access denied!")
        return
    
    keyboard = [
        [InlineKeyboardButton("📱 Get VPN Config", callback_data='get_config')],
        [InlineKeyboardButton("📊 Server Status", callback_data='status')],
        [InlineKeyboardButton("🔧 Restart VPN", callback_data='restart')],
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"👋 Hi {user.first_name}!\n"
        "VPN Management Bot\n"
        "Choose an option:",
        reply_markup=reply_markup
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle button presses"""
    query = update.callback_query
    await query.answer()
    
    if query.from_user.id != ADMIN_ID:
        return
    
    if query.data == 'get_config':
        # Get VPN config
        try:
            with open('/etc/hysteria/config.yaml', 'r') as f:
                content = f.read()
                # Extract password
                import re
                password_match = re.search(r'password:\s*"([^"]+)"', content)
                password = password_match.group(1) if password_match else "Not found"
            
            # Get server IP
            ip = subprocess.getoutput("curl -s ifconfig.me")
            
            # Create config link
            config_url = f"hy2://{password}@{ip}:443?sni=vpn.example.com&insecure=1&alpn=h3"
            
            await query.edit_message_text(
                f"🔐 *VPN Configuration*\n\n"
                f"📍 Server: `{ip}`\n"
                f"🔑 Password: `{password}`\n"
                f"🌐 Port: `443`\n\n"
                f"📱 *Mobile config:*\n`{config_url}`",
                parse_mode='Markdown'
            )
        except Exception as e:
            await query.edit_message_text(f"❌ Error: {str(e)}")
    
    elif query.data == 'status':
        # Check VPN status
        try:
            status = subprocess.getoutput("systemctl is-active hysteria")
            ip = subprocess.getoutput("curl -s ifconfig.me")
            
            status_text = "🟢 Active" if status == "active" else "🔴 Inactive"
            
            await query.edit_message_text(
                f"📊 *Server Status*\n\n"
                f"• VPN: {status_text}\n"
                f"• IP: `{ip}`\n"
                f"• Uptime: {subprocess.getoutput('uptime -p')}",
                parse_mode='Markdown'
            )
        except Exception as e:
            await query.edit_message_text(f"❌ Error: {str(e)}")
    
    elif query.data == 'restart':
        # Restart VPN
        try:
            subprocess.run(["sudo", "systemctl", "restart", "hysteria"], check=True)
            await query.edit_message_text("✅ VPN restarted successfully!")
        except Exception as e:
            await query.edit_message_text(f"❌ Error: {str(e)}")

def main():
    """Start the bot"""
    # Create application
    application = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button_handler))
    
    # Start bot
    logger.info("Bot is starting...")
    application.run_polling()

if __name__ == '__main__':
    main()
