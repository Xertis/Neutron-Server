import { defineConfig } from 'vitepress'

export default defineConfig({
    lang: 'ru-RU',
    title: 'Neutron',
    description: 'Документация серверного ядра Neutron для VoxelCore',
    base: '/Neutron-Server/',
    lastUpdated: true,

    head: [
        ['link', { rel: 'icon', type: 'image/png', href: '/docs_icon.png' }],
    ],

  themeConfig: {
        logo: '/docs_icon.png',

        nav: [
            { text: 'Начало', link: '/core/creating-server' },
            { text: 'API', link: '/api/' },
            { text: 'Оболочки', link: '/shells/' },
        ],

        sidebar: {
            '/api/': [
                {
                    text: 'API Ядра',
                    items: [
                        { text: 'Главная', link: '/api/' },
                        { text: 'Языковой сервер', link: '/api/language-server' },
                    ],
                },
                {
                    text: 'Библиотеки',
                    collapsed: false,
                    items: [
                        { text: 'Дата-классы', link: '/api/libraries/extra-classes' },

                        { text: 'Стандартные ивенты', link: '/api/libraries/std-events' },

                        { text: 'Сетевые ивенты', link: '/api/libraries/events' },
                        { text: 'Сетевые сообщения', link: '/api/libraries/messages' },

                        { text: 'Сериализация таблиц', link: '/api/libraries/bson' },
                        { text: 'Сериализация данных инвентарей', link: '/api/libraries/inventory-data' },

                        { text: 'Репликации', link: '/api/libraries/replications' },

                        { text: 'Аккаунты', link: '/api/libraries/accounts' },
                        { text: 'Песочница', link: '/api/libraries/sandbox' },
                        { text: 'Синхронизация сущностей', link: '/api/libraries/entities' },
                        { text: 'Правила игрока и мира', link: '/api/libraries/rules' },
                        { text: 'Консоль', link: '/api/libraries/console' },

                        { text: 'Контроль пакетов', link: '/api/libraries/interceptors' },
                        { text: 'Отправка пакетов', link: '/api/libraries/protocol' },

                        { text: 'Задачи', link: '/api/libraries/tasks' },
                        {
                            text: 'Управление клиентскими эффектами',
                            collapsed: true,
                            items: [
                                { text: 'звук', link: '/api/libraries/effects/audio' },
                                { text: 'обёртки блоков', link: '/api/libraries/effects/blockwraps' },
                                { text: 'частицы', link: '/api/libraries/effects/particles' },
                                { text: '3D текст', link: '/api/libraries/effects/text3d' },
                            ],
                        },
                    ],
                },
                {
                    text: 'Утилиты',
                    collapsed: false,
                    items: [
                        { text: 'Об утилитах', link: '/api/utils/about' },
                        { text: 'Модуль разделённой логики', link: '/api/utils/module' },
                    ],
                },
            ],
            '/core/': [
                {
                    text: 'Ядро',
                    items: [
                        { text: 'Создание сервера', link: '/core/creating-server' },
                        { text: 'Конфиг сервера', link: '/core/server-config' },
                        { text: 'Терминал сервера', link: '/core/server-terminal' },
                    ],
                },
            ],
            '/shells/': [
                {
                    text: 'Оболочки и расширения',
                    items: [
                        { text: 'Обзор', link: '/shells/' },
                    ],
                },
            ],
        },

        socialLinks: [
            { icon: 'github', link: 'https://github.com/Xertis/Neutron-Server' },
        ],

        docFooter: {
            prev: 'Предыдущая страница',
            next: 'Следующая страница',
        },

        outline: {
            label: 'На этой странице',
        },

        lastUpdated: {
            text: 'Обновлено',
        },
    },
})
