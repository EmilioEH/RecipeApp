import SwiftUI
import UniformTypeIdentifiers

// iOS 14+ Compatible Recipe App

// MARK: - Data Models
struct Recipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var ingredients: [String]
    var instructions: String
    var prepTime: Int
    var cookTime: Int
    var servings: Int
    var category: RecipeCategory
    var notes: String
    var rating: Double
    var lastModified: Date
    var lastModifiedBy: String
    
    var totalTime: Int {
        prepTime + cookTime
    }
    
    init(name: String, ingredients: [String], instructions: String, prepTime: Int, cookTime: Int, servings: Int, category: RecipeCategory, notes: String = "", rating: Double = 0) {
        self.id = UUID()
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.category = category
        self.notes = notes
        self.rating = rating
        self.lastModified = Date()
        self.lastModifiedBy = UIDevice.current.name
    }
}

enum RecipeCategory: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case dessert = "Dessert"
    case snack = "Snack"
    case beverage = "Beverage"
    
    var icon: String {
        switch self {
        case .breakfast: return "sun.max.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.fill"
        case .dessert: return "birthday.cake.fill"
        case .snack: return "carrot.fill"
        case .beverage: return "cup.and.saucer.fill"
        }
    }
}

struct RecipeData: Codable {
    var recipes: [Recipe]
    var lastSyncDate: Date
}

// MARK: - Storage Manager
class RecipeStorageManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var storageURL: URL?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var hasUnsavedChanges = false
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "RecipeStorageURL"
    private let fileName = "recipes.json"
    
    init() {
        loadStorageURL()
        if storageURL != nil {
            loadRecipes()
        }
    }
    
    private func loadStorageURL() {
        if let bookmarkData = userDefaults.data(forKey: storageKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                if !isStale {
                    storageURL = url
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
    }
    
    func selectStorageFolder(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil)
            userDefaults.set(bookmarkData, forKey: storageKey)
            storageURL = url
            loadRecipes()
        } catch {
            lastError = "Failed to save storage location: \(error.localizedDescription)"
        }
    }
    
    func loadRecipes() {
        guard let folderURL = storageURL else { return }
        
        isLoading = true
        lastError = nil
        
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let recipeData = try JSONDecoder().decode(RecipeData.self, from: data)
                self.recipes = recipeData.recipes
                hasUnsavedChanges = false
            } catch {
                lastError = "Failed to load recipes: \(error.localizedDescription)"
                // Load sample recipes on error
                loadSampleRecipes()
            }
        } else {
            // First time - create file with sample recipes
            loadSampleRecipes()
            saveRecipes()
        }
        
        isLoading = false
    }
    
    func saveRecipes() {
        guard let folderURL = storageURL else { return }
        
        let fileURL = folderURL.appendingPathComponent(fileName)
        let recipeData = RecipeData(recipes: recipes, lastSyncDate: Date())
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recipeData)
            try data.write(to: fileURL)
            hasUnsavedChanges = false
        } catch {
            lastError = "Failed to save recipes: \(error.localizedDescription)"
        }
    }
    
    func addRecipe(_ recipe: Recipe) {
        var newRecipe = recipe
        newRecipe.lastModified = Date()
        newRecipe.lastModifiedBy = UIDevice.current.name
        recipes.append(newRecipe)
        saveRecipes()
    }
    
    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            var updatedRecipe = recipe
            updatedRecipe.lastModified = Date()
            updatedRecipe.lastModifiedBy = UIDevice.current.name
            recipes[index] = updatedRecipe
            saveRecipes()
        }
    }
    
    func deleteRecipe(at offsets: IndexSet) {
        recipes.remove(atOffsets: offsets)
        saveRecipes()
    }
    
    func checkForConflicts(completion: @escaping (Bool, RecipeData?) -> Void) {
        guard let folderURL = storageURL else {
            completion(false, nil)
            return
        }
        
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let diskData = try JSONDecoder().decode(RecipeData.self, from: data)
            
            // Check if file has been modified since we last loaded
            let hasConflicts = diskData.lastSyncDate > RecipeData(recipes: recipes, lastSyncDate: Date()).lastSyncDate
            
            completion(hasConflicts, hasConflicts ? diskData : nil)
        } catch {
            completion(false, nil)
        }
    }
    
    func resolveConflicts(useRemoteData: Bool, remoteData: RecipeData?) {
        if useRemoteData, let remoteData = remoteData {
            self.recipes = remoteData.recipes
        }
        saveRecipes()
    }
    
    private func loadSampleRecipes() {
        recipes = [
            Recipe(
                name: "Classic Pancakes",
                ingredients: ["2 cups flour", "2 eggs", "1.5 cups milk", "2 tbsp sugar", "2 tsp baking powder", "1/2 tsp salt", "2 tbsp melted butter"],
                instructions: "1. Mix dry ingredients in a bowl\n2. Whisk wet ingredients separately\n3. Combine and mix until just blended\n4. Cook on griddle until bubbles form\n5. Flip and cook until golden",
                prepTime: 10,
                cookTime: 15,
                servings: 4,
                category: .breakfast,
                notes: "For fluffier pancakes, let the batter rest for 5 minutes before cooking. You can also add blueberries or chocolate chips!",
                rating: 5
            ),
            Recipe(
                name: "Caesar Salad",
                ingredients: ["1 head romaine lettuce", "1/2 cup Caesar dressing", "1/4 cup parmesan cheese", "1 cup croutons", "2 tbsp lemon juice"],
                instructions: "1. Wash and chop lettuce\n2. Toss with dressing\n3. Add parmesan and croutons\n4. Squeeze lemon juice on top\n5. Serve immediately",
                prepTime: 15,
                cookTime: 0,
                servings: 2,
                category: .lunch,
                notes: "",
                rating: 4
            ),
            Recipe(
                name: "Spaghetti Carbonara",
                ingredients: ["1 lb spaghetti", "4 eggs", "1 cup parmesan", "8 oz pancetta", "Black pepper", "Salt"],
                instructions: "1. Cook spaghetti al dente\n2. Fry pancetta until crispy\n3. Beat eggs with cheese\n4. Toss hot pasta with pancetta\n5. Remove from heat, add egg mixture\n6. Season with pepper",
                prepTime: 10,
                cookTime: 20,
                servings: 4,
                category: .dinner,
                notes: "The key is to work quickly and keep the pasta hot, but remove from direct heat when adding eggs to avoid scrambling them.",
                rating: 5
            )
        ]
    }
}

// MARK: - Main App
@main
struct RecipeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Star Rating View
struct StarRatingView: View {
    @Binding var rating: Double
    var interactive: Bool = true
    var starSize: CGFloat = 20
    var showEmptyStars: Bool = true
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starType(for: star))
                    .font(.system(size: starSize))
                    .foregroundColor(Double(star) <= rating ? .yellow : Color.gray.opacity(showEmptyStars ? 0.3 : 0))
                    .onTapGesture {
                        if interactive {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                // If tapping the same star, clear rating
                                if rating == Double(star) {
                                    rating = 0
                                } else {
                                    rating = Double(star)
                                }
                            }
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
            }
        }
    }
    
    func starType(for star: Int) -> String {
        if Double(star) <= rating {
            return "star.fill"
        } else if Double(star) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var storageManager = RecipeStorageManager()
    @State private var showingAddRecipe = false
    @State private var showingFolderPicker = false
    @State private var searchText = ""
    @State private var showingConflictAlert = false
    @State private var conflictData: RecipeData?
    @State private var sortOption: SortOption = .name
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case rating = "Rating"
        case recent = "Recently Modified"
        case favorites = "Favorites First"
        
        var systemImage: String {
            switch self {
            case .name: return "textformat"
            case .rating: return "star"
            case .recent: return "clock"
            case .favorites: return "heart"
            }
        }
    }
    
    var filteredRecipes: [Recipe] {
        let filtered = searchText.isEmpty ? storageManager.recipes : storageManager.recipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
        
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .rating:
            return filtered.sorted { $0.rating > $1.rating }
        case .recent:
            return filtered.sorted { $0.lastModified > $1.lastModified }
        case .favorites:
            return filtered.sorted {
                if $0.rating == 5 && $1.rating != 5 {
                    return true
                } else if $0.rating != 5 && $1.rating == 5 {
                    return false
                } else {
                    return $0.name < $1.name
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if storageManager.storageURL == nil {
                    StorageSetupView(showingFolderPicker: $showingFolderPicker)
                } else {
                    VStack(spacing: 0) {
                        // Custom search bar for iOS 14 compatibility
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search recipes...", text: $searchText)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Sort indicator
                        if sortOption != .name {
                            HStack {
                                Image(systemName: sortOption.systemImage)
                                    .font(.caption)
                                Text("Sorted by \(sortOption.rawValue)")
                                    .font(.caption)
                                Spacer()
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        }
                        
                        List {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe, storageManager: storageManager)) {
                                    RecipeRowView(recipe: recipe)
                                }
                            }
                            .onDelete(perform: deleteRecipes)
                        }
                    }
                    .onAppear {
                        // Refresh on appear
                        refreshRecipesSync()
                    }
                }
            }
            .navigationTitle("My Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if storageManager.storageURL != nil {
                        Menu {
                            Button(action: refreshRecipesSync) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            
                            Divider()
                            
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button(action: { sortOption = option }) {
                                        Label(option.rawValue, systemImage: option.systemImage)
                                    }
                                }
                            } label: {
                                Label("Sort By", systemImage: "arrow.up.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if storageManager.storageURL != nil {
                        Button(action: { showingAddRecipe = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddRecipeView(storageManager: storageManager)
            }
            .sheet(isPresented: $showingFolderPicker) {
                DocumentPicker(storageManager: storageManager)
            }
            .alert("Sync Conflict", isPresented: $showingConflictAlert) {
                Button("Use My Changes") {
                    storageManager.resolveConflicts(useRemoteData: false, remoteData: nil)
                }
                Button("Use Their Changes") {
                    storageManager.resolveConflicts(useRemoteData: true, remoteData: conflictData)
                }
            } message: {
                Text("The recipes have been modified by \(conflictData?.recipes.first?.lastModifiedBy ?? "another device"). Which version would you like to keep?")
            }
        }
    }
    
    func deleteRecipes(at offsets: IndexSet) {
        storageManager.deleteRecipe(at: offsets)
    }
    
    func refreshRecipesSync() {
        storageManager.checkForConflicts { hasConflicts, remoteData in
            if hasConflicts {
                conflictData = remoteData
                showingConflictAlert = true
            } else {
                storageManager.loadRecipes()
            }
        }
    }
}

struct StorageSetupView: View {
    @Binding var showingFolderPicker: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Choose Recipe Storage")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Select a folder where your recipes will be stored. Choose an iCloud Drive folder to sync across devices and share with family.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: { showingFolderPicker = true }) {
                Label("Select Folder", systemImage: "folder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let storageManager: RecipeStorageManager
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access folder")
                return
            }
            
            parent.storageManager.selectStorageFolder(url: url)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct RecipeRowView: View {
    let recipe: Recipe
    
    var body: some View {
        HStack {
            Image(systemName: recipe.category.icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.name)
                        .font(.headline)
                    if recipe.rating == 5 {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if recipe.rating > 0 {
                    StarRatingView(rating: .constant(recipe.rating), interactive: false, starSize: 12)
                }
                
                HStack {
                    Label("\(recipe.totalTime) min", systemImage: "clock")
                    Label("\(recipe.servings)", systemImage: "person.2")
                    if !recipe.notes.isEmpty {
                        Label("Notes", systemImage: "note.text")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text("Modified by \(recipe.lastModifiedBy)")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    let storageManager: RecipeStorageManager
    @State private var showingEditView = false
    @State private var currentRating: Double
    
    init(recipe: Recipe, storageManager: RecipeStorageManager) {
        self.recipe = recipe
        self.storageManager = storageManager
        self._currentRating = State(initialValue: recipe.rating)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: recipe.category.icon)
                            .font(.title)
                            .foregroundColor(.blue)
                        Text(recipe.category.rawValue)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Rating
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentRating > 0 ? "Your Rating" : "Rate this recipe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        StarRatingView(rating: Binding(
                            get: { currentRating },
                            set: { newValue in
                                currentRating = newValue
                                var updatedRecipe = recipe
                                updatedRecipe.rating = newValue
                                storageManager.updateRecipe(updatedRecipe)
                            }
                        ))
                    }
                    
                    HStack(spacing: 20) {
                        Label("Prep: \(recipe.prepTime) min", systemImage: "timer")
                        Label("Cook: \(recipe.cookTime) min", systemImage: "flame")
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    Text("Last modified by \(recipe.lastModifiedBy) on \(recipe.lastModified, style: .date)")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.6))
                }
                .padding(.horizontal)
                
                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                                Text(ingredient)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(recipe.instructions)
                        .padding(.horizontal)
                        .lineSpacing(4)
                }
                
                // Notes
                if !recipe.notes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.blue)
                            Text("Notes")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        Text(recipe.notes)
                            .padding(.horizontal)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditView = true
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditRecipeView(recipe: recipe, storageManager: storageManager)
        }
    }
}

struct AddRecipeView: View {
    @ObservedObject var storageManager: RecipeStorageManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var ingredientText = ""
    @State private var ingredients: [String] = []
    @State private var instructions = ""
    @State private var prepTime = 15
    @State private var cookTime = 30
    @State private var servings = 4
    @State private var category = RecipeCategory.dinner
    @State private var notes = ""
    @State private var rating: Double = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe Info") {
                    TextField("Recipe Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Rating")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        StarRatingView(rating: $rating)
                    }
                }
                
                Section("Time & Servings") {
                    Stepper("Prep Time: \(prepTime) min", value: $prepTime, in: 0...120, step: 5)
                    Stepper("Cook Time: \(cookTime) min", value: $cookTime, in: 0...180, step: 5)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...12)
                }
                
                Section("Ingredients") {
                    HStack {
                        TextField("Add ingredient", text: $ingredientText)
                        Button("Add") {
                            if !ingredientText.isEmpty {
                                ingredients.append(ingredientText)
                                ingredientText = ""
                            }
                        }
                        .disabled(ingredientText.isEmpty)
                    }
                    
                    ForEach(ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                    }
                    .onDelete { indexSet in
                        ingredients.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newRecipe = Recipe(
                            name: name,
                            ingredients: ingredients,
                            instructions: instructions,
                            prepTime: prepTime,
                            cookTime: cookTime,
                            servings: servings,
                            category: category,
                            notes: notes,
                            rating: rating
                        )
                        storageManager.addRecipe(newRecipe)
                        dismiss()
                    }
                    .disabled(name.isEmpty || ingredients.isEmpty || instructions.isEmpty)
                }
            }
        }
    }
}

struct EditRecipeView: View {
    let recipe: Recipe
    @ObservedObject var storageManager: RecipeStorageManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var ingredientText = ""
    @State private var ingredients: [String]
    @State private var instructions: String
    @State private var prepTime: Int
    @State private var cookTime: Int
    @State private var servings: Int
    @State private var category: RecipeCategory
    @State private var notes: String
    @State private var rating: Double
    
    init(recipe: Recipe, storageManager: RecipeStorageManager) {
        self.recipe = recipe
        self.storageManager = storageManager
        _name = State(initialValue: recipe.name)
        _ingredients = State(initialValue: recipe.ingredients)
        _instructions = State(initialValue: recipe.instructions)
        _prepTime = State(initialValue: recipe.prepTime)
        _cookTime = State(initialValue: recipe.cookTime)
        _servings = State(initialValue: recipe.servings)
        _category = State(initialValue: recipe.category)
        _notes = State(initialValue: recipe.notes)
        _rating = State(initialValue: recipe.rating)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe Info") {
                    TextField("Recipe Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Rating")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        StarRatingView(rating: $rating)
                    }
                }
                
                Section("Time & Servings") {
                    Stepper("Prep Time: \(prepTime) min", value: $prepTime, in: 0...120, step: 5)
                    Stepper("Cook Time: \(cookTime) min", value: $cookTime, in: 0...180, step: 5)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...12)
                }
                
                Section("Ingredients") {
                    HStack {
                        TextField("Add ingredient", text: $ingredientText)
                        Button("Add") {
                            if !ingredientText.isEmpty {
                                ingredients.append(ingredientText)
                                ingredientText = ""
                            }
                        }
                        .disabled(ingredientText.isEmpty)
                    }
                    
                    ForEach(ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                    }
                    .onDelete { indexSet in
                        ingredients.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedRecipe = recipe
                        updatedRecipe.name = name
                        updatedRecipe.ingredients = ingredients
                        updatedRecipe.instructions = instructions
                        updatedRecipe.prepTime = prepTime
                        updatedRecipe.cookTime = cookTime
                        updatedRecipe.servings = servings
                        updatedRecipe.category = category
                        updatedRecipe.notes = notes
                        updatedRecipe.rating = rating
                        
                        storageManager.updateRecipe(updatedRecipe)
                        dismiss()
                    }
                    .disabled(name.isEmpty || ingredients.isEmpty || instructions.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
// Note: This app targets iOS 14.0+
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
