const fs = require('fs');
const dotenv = require('dotenv')

const contract_path = './contracts/'
var contracts =[];

// store all contract files
fs.readdirSync(contract_path).forEach(file => {
    if (file[file.length - 3] == '.'){
            contracts[contracts.length] = file;
    }
});

// load env
const envConfig = dotenv.parse(fs.readFileSync('.env'))
for (let k in envConfig) {
  process.env[k] = envConfig[k]
}

var variables = [];
var idx;
function inject() {
    for (var i = 0; i < contracts.length; i++){
        path = './contracts/' + contracts[i];
        var data = fs.readFileSync(path, 'utf-8');

        for (var j = 0; j < data.length; j++) {
            if (data[j] == '$' && data[j + 1] == '{') {
                idx = j + 2;
                var variable = '';
                while (data[idx] != '}') {
                    variable = variable + data[idx];
                    idx += 1;
                }
                env_value = process.env[variable];
                console.log(env_value);
                data = data.replace('${' + variable + '}', env_value);

                j = j + variable.length;
                if (!variables.includes(variable)) {
                    variables[variables.length] = variable;
                }
            }
        }
        fs.writeFileSync(path, data);
    }
}
inject();
