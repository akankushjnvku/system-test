// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <algorithm>
#include <cassert>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

using StringVector = std::vector<std::string>;
using IntVector = std::vector<int>;

class RandomStrings {
private:
    StringVector _strings;

    StringVector gen_strings(size_t count, size_t offset) {
        StringVector result;
        for (size_t i = offset; i < (count + offset); ++i) {
            char str[7];
            snprintf(str, 7, "%06d", i);
            result.push_back(std::string(str));
        }
        return result;
    }

public:
    RandomStrings(size_t count, size_t offset = 0)
        : _strings(gen_strings(count, offset))
    {
    }

    const StringVector& get() const { return _strings; }

    StringVector get_rnd(size_t count) {
        assert(count <= _strings.size());
        StringVector result(count);
        std::random_shuffle(_strings.begin(), _strings.end());
        std::copy_n(_strings.begin(), count, result.begin());
        return result;
    }
};

IntVector make_rnd_vector(size_t count) {
    IntVector result;
    result.reserve(count);
    for (size_t i = 0; i < count; ++i) {
        result.push_back(std::rand()%100);
    }
    return result;
}

std::ostream& print_vector(std::ostream& os, const IntVector& vec) {
    os << "[";
    for (size_t i = 0; i < vec.size(); ++i) {
        if (i != 0) os << ",";
        os << vec[i] << ".0";
    }
    return os << "]";
}

std::ostream& print_model_tensor(std::ostream& os, const StringVector& cats, size_t vec_size) {
    os << "\"blocks\":{";
    for (size_t i = 0; i < cats.size(); ++i) {
        if (i != 0) os << ",\n";
        os << "\"" << cats[i] << "\":";
        print_vector(os, make_rnd_vector(vec_size));
    }
    return os << "}";
}

std::ostream& print_models_tensor(std::ostream& os, const StringVector& models, const StringVector& cats, size_t vec_size) {
    os << "\"blocks\":[";
    for (size_t i = 0; i < models.size(); ++i) {
        if (i != 0) os << ",\n";
        const auto& model = models[i];
        for (size_t j = 0; j < cats.size(); ++j) {
            if (j != 0) os << ",\n";
            const auto& cat = cats[j];
            os << "{ \"address\": {\"model\":\"" << model << "\",\"cat\":\"" << cat << "\"}, \"values\":";
            print_vector(os, make_rnd_vector(vec_size));
            os << "}";
        }
    }
    return os << "]";
}

void print_puts(std::ostream& os, const StringVector& models, RandomStrings& strings,
                size_t num_docs, size_t num_cats_per_doc, size_t vec_size, const std::string& field) {
    os << "[\n";
    for (size_t i = 0; i < num_docs; ++i) {
        if (i != 0) os << ",\n";
        auto cats = strings.get_rnd(num_cats_per_doc);
        os << "{\"put\":\"id:test:test::" << i << "\",\"fields\":{\n";
        os << "\"id\":" << i << ",";
        if (field == "all") {
            os << "\"model\":{"; print_model_tensor(os, cats, vec_size) << "},";
            os << "\"models\":{"; print_models_tensor(os, models, cats, vec_size) << "}";
        } else if (field == "model") {
            os << "\"model\":{"; print_model_tensor(os, cats, vec_size) << "}";
        } else if (field == "models") {
            os << "\"models\":{"; print_models_tensor(os, models, cats, vec_size) << "}";
        }
        os << "}}";
    }
    os << "]\n";
}

void print_updates(std::ostream& os, const std::string& type, const StringVector& models, RandomStrings& strings,
                   size_t num_docs, size_t num_cats_per_doc, size_t vec_size, const std::string& field) {
    os << "[\n";
    for (size_t i = 0; i < num_docs; ++i) {
        if (i != 0) os << ",\n";
        auto cats = strings.get_rnd(num_cats_per_doc);
        os << "{\"update\":\"id:test:test::" << i << "\",\"fields\":{\n";
        if (field == "model") {
            os << "\"model\":{\"" << type << "\":{"; print_model_tensor(os, cats, vec_size) << "}}";
        } else if (field == "models") {
            os << "\"models\":{\"" << type << "\":{"; print_models_tensor(os, models, cats, vec_size) << "}}";
        }
        os << "}}";
    }
    os << "]\n";
}


const std::string LB = "%7B";
const std::string RB = "%7D";

void print_query_tensor(std::ostream& os, const std::string& dim_name, const StringVector& values, bool rnd_value) {
    os << LB;
    for (size_t i = 0; i < values.size(); ++i) {
        if (i != 0) os << ",";
        os << LB << dim_name << ":" << values[i] << RB << ":" << (rnd_value ? (std::rand()%100) : 1) << ".0";
    }
    os << RB;
}

void print_query_cat_tensor(std::ostream& os, const StringVector& cats, bool rnd_value) {
    print_query_tensor(os, "cat", cats, rnd_value);
}

void print_query_model_tensor(std::ostream& os, const StringVector& model) {
    assert(model.size() == 1);
    print_query_tensor(os, "model", model, false);
}

void print_query(std::ostream& os, RandomStrings& models, RandomStrings& categories,
                 size_t num_cats_per_query, size_t vec_size, bool single_model) {
    auto cats = categories.get_rnd(num_cats_per_query);
    os << "/search/?query=sddocname:test";
    os << "&ranking.features.query(q_cat_keys)="; print_query_cat_tensor(os, cats, false);
    os << "&ranking.features.query(q_cat_scores)="; print_query_cat_tensor(os, cats, true);
    if (!single_model) {
        os << "&ranking.features.query(q_model)="; print_query_model_tensor(os, models.get_rnd(1));
    }
    os << "&ranking.features.query(q_user_vec)="; print_vector(os, make_rnd_vector(vec_size));
}

void print_queries(std::ostream& os, RandomStrings& models, RandomStrings& categories,
                   size_t num_queries, size_t num_cats_per_query, size_t vec_size, bool single_model) {
    for (size_t i = 0; i < num_queries; ++i) {
        print_query(os, models, categories, num_cats_per_query, vec_size, single_model);
        os << std::endl;
    }
}

void print_usage(char* argv[]) {
    std::cerr << argv[0] << " puts <field> <num docs> | updates <type> <field> <num docs> | queries <type> <num queries>" << std::endl;
}

int main (int argc, char* argv[]) {
    if (argc < 3 || argc > 5) {
        print_usage(argv);
        return 1;
    }
    std::srand(12345);
    std::string mode(argv[1]);
    size_t num_cats = 50;
    size_t num_cats_per_doc = 3;
    size_t num_cats_per_query = 10;
    size_t num_models = 10;
    size_t vec_size = 256;
    RandomStrings strings(num_cats);
    RandomStrings models(num_models);
    RandomStrings strings_2(num_cats, num_cats);
    RandomStrings models_2(1, num_models);
    if (mode == "puts") {
        std::string field(argv[2]);
        size_t num_docs = strtoul(argv[3], nullptr, 0);
        print_puts(std::cout, models.get(), strings, num_docs, num_cats_per_doc, vec_size, field);
    } else if (mode == "updates") {
        std::string type(argv[2]);
        std::string field(argv[3]);
        size_t num_docs = strtoul(argv[4], nullptr, 0);
        if (type == "assign") {
            print_updates(std::cout, "assign", models.get(), strings, num_docs, num_cats_per_doc, vec_size, field);
        } else if (type == "add") {
            // When updating the single model tensor we add a single category.
            // When updating the multi-model tensor we add an entire new model.
            print_updates(std::cout, "add", models_2.get(), strings_2, num_docs,
                          (field == "model") ? 1 : num_cats_per_doc, vec_size, field);
        } else {
            print_usage(argv);
            return 1;
        }
    } else if (mode == "queries") {
        std::string type(argv[2]);
        size_t num_queries = strtoul(argv[3], nullptr, 0);
        if (type == "single") {
            print_queries(std::cout, models, strings, num_queries, num_cats_per_query, vec_size, true);
        } else if (type == "multi") {
            print_queries(std::cout, models, strings, num_queries, num_cats_per_query, vec_size, false);
        } else {
            print_usage(argv);
            return 1;
        }
    } else {
        print_usage(argv);
        return 1;
    }
    return 0;
}


