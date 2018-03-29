var https = require('https');

exports.handler = (event, context, callback) => {
    
    var licenseKey = process.env.ActivationKey
    var deploymentID = process.env.DeploymentID
    
    var deactivateURL = `https://activation.dl.opswat.com/deactivation?key=${licenseKey}&deployment=${deploymentID}`
    
    console.log('\n deactivateURL: ' + deactivateURL)

    https.get(deactivateURL, function(res) {
        console.log("Deactivate response: " + res.statusCode);
        context.succeed();        
    })

    callback(null, 'success');
};