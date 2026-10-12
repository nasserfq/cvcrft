import React from 'react';
import CvGenerationShow from '../components/CvGenerationShow';

const CvGenerationShowPage = () => {
  // Get the CV generation ID from the URL
  const pathParts = window.location.pathname.split('/');
  const cvGenerationId = pathParts[pathParts.length - 1];

  // Validate that we have a valid ID
  if (!cvGenerationId || isNaN(parseInt(cvGenerationId))) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center py-12">
          <div className="text-red-500 text-lg mb-4">❌ Invalid CV Generation ID</div>
          <button
            onClick={() => window.location.href = '/cv_generations'}
            className="bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded"
          >
            Back to CV Generations
          </button>
        </div>
      </div>
    );
  }

  return <CvGenerationShow cvGenerationId={cvGenerationId} />;
};

export default CvGenerationShowPage;