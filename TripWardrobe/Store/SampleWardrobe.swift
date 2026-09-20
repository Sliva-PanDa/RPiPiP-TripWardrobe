import Foundation

/// Демонстрационное наполнение гардероба для лабораторной работы № 1.
/// Начиная с лабораторной работы № 3 эти данные заменяются записями базы данных.
enum SampleWardrobe {
    static let seasons: [SeasonStyle] = [
        SeasonStyle(
            name: "Лето · Casual",
            icon: "sun.max",
            looks: [
                Look(name: "Городская прогулка", occasion: "Повседневный", items: [
                    WardrobeItem(name: "Футболка белая", category: "Верх", icon: "tshirt",
                                 weightGrams: 180, status: .inCloset,
                                 note: "хлопок, быстро сохнет"),
                    WardrobeItem(name: "Шорты джинсовые", category: "Низ", icon: "figure.stand",
                                 weightGrams: 420, status: .inCloset),
                    WardrobeItem(name: "Кеды парусиновые", category: "Обувь", icon: "figure.walk",
                                 weightGrams: 760, status: .inLaundry,
                                 note: "постирать перед поездкой"),
                    WardrobeItem(name: "Кепка", category: "Аксессуары", icon: "eyeglasses",
                                 weightGrams: 90, status: .inCloset)
                ]),
                Look(name: "Пляжный день", occasion: "Отдых", items: [
                    WardrobeItem(name: "Плавки", category: "Низ", icon: "drop",
                                 weightGrams: 120, status: .inTrip),
                    WardrobeItem(name: "Рубашка льняная", category: "Верх", icon: "tshirt",
                                 weightGrams: 240, status: .inTrip,
                                 note: "лён, не мнётся в чемодане"),
                    WardrobeItem(name: "Полотенце пляжное", category: "Текстиль", icon: "square.grid.2x2",
                                 weightGrams: 480, status: .inTrip),
                    WardrobeItem(name: "Сланцы", category: "Обувь", icon: "figure.walk",
                                 weightGrams: 310, status: .inTrip)
                ])
            ]
        ),
        SeasonStyle(
            name: "Демисезон · Бизнес",
            icon: "briefcase",
            looks: [
                Look(name: "Деловая встреча", occasion: "Официальный", items: [
                    WardrobeItem(name: "Пиджак шерстяной", category: "Верх", icon: "person.crop.square",
                                 weightGrams: 980, status: .inCloset,
                                 note: "везти на вешалке"),
                    WardrobeItem(name: "Брюки классические", category: "Низ", icon: "figure.stand",
                                 weightGrams: 540, status: .inCloset),
                    WardrobeItem(name: "Рубашка голубая", category: "Верх", icon: "tshirt",
                                 weightGrams: 260, status: .inLaundry),
                    WardrobeItem(name: "Туфли оксфорды", category: "Обувь", icon: "figure.walk",
                                 weightGrams: 1120, status: .inCloset),
                    WardrobeItem(name: "Ремень кожаный", category: "Аксессуары", icon: "minus.rectangle",
                                 weightGrams: 180, status: .inCloset)
                ]),
                Look(name: "Smart casual", occasion: "Полуофициальный", items: [
                    WardrobeItem(name: "Джемпер тонкий", category: "Верх", icon: "tshirt",
                                 weightGrams: 430, status: .inCloset),
                    WardrobeItem(name: "Чиносы бежевые", category: "Низ", icon: "figure.stand",
                                 weightGrams: 500, status: .inTrip),
                    WardrobeItem(name: "Лоферы", category: "Обувь", icon: "figure.walk",
                                 weightGrams: 890, status: .inCloset)
                ])
            ]
        ),
        SeasonStyle(
            name: "Зима · Горы",
            icon: "snowflake",
            looks: [
                Look(name: "Горнолыжный день", occasion: "Спорт", items: [
                    WardrobeItem(name: "Пуховик", category: "Верх", icon: "cloud.snow",
                                 weightGrams: 1450, status: .inCloset,
                                 note: "сжимать в компрессионный мешок"),
                    WardrobeItem(name: "Термобельё", category: "Бельё", icon: "thermometer.medium",
                                 weightGrams: 280, status: .inCloset),
                    WardrobeItem(name: "Брюки утеплённые", category: "Низ", icon: "figure.skiing.downhill",
                                 weightGrams: 860, status: .inCloset),
                    WardrobeItem(name: "Перчатки горнолыжные", category: "Аксессуары", icon: "hand.raised",
                                 weightGrams: 220, status: .inLaundry),
                    WardrobeItem(name: "Ботинки зимние", category: "Обувь", icon: "figure.walk",
                                 weightGrams: 1680, status: .inCloset,
                                 note: "надевать в самолёт, экономит 1,7 кг")
                ]),
                Look(name: "Вечер в шале", occasion: "Повседневный", items: [
                    WardrobeItem(name: "Свитер шерстяной", category: "Верх", icon: "tshirt",
                                 weightGrams: 620, status: .inCloset),
                    WardrobeItem(name: "Джинсы утеплённые", category: "Низ", icon: "figure.stand",
                                 weightGrams: 720, status: .inCloset),
                    WardrobeItem(name: "Носки шерстяные", category: "Бельё", icon: "thermometer",
                                 weightGrams: 110, status: .inLaundry)
                ])
            ]
        )
    ]
}
