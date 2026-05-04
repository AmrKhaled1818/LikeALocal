import { useState } from 'react';
import { useNavigate } from 'react-router';
import { MapPin, Image as ImageIcon, X } from 'lucide-react';
import { toast } from 'sonner';

const GEM_TYPES = [
  { value: 'restaurant', label: 'Restaurant' },
  { value: 'bar', label: 'Bar' },
  { value: 'cafe', label: 'Café' },
  { value: 'park', label: 'Park' },
  { value: 'viewpoint', label: 'Viewpoint' },
  { value: 'shop', label: 'Shop' },
  { value: 'museum', label: 'Museum' },
  { value: 'beach', label: 'Beach' },
  { value: 'trail', label: 'Trail' },
  { value: 'other', label: 'Other' },
];

export function CreatePostScreen() {
  const navigate = useNavigate();
  const [caption, setCaption] = useState('');
  const [location, setLocation] = useState('');
  const [selectedType, setSelectedType] = useState('');
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setImagePreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleRemoveImage = () => {
    setImagePreview(null);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!caption.trim()) {
      toast.error('Please add a caption');
      return;
    }

    if (!location.trim()) {
      toast.error('Please add a location');
      return;
    }

    if (!selectedType) {
      toast.error('Please select a gem type');
      return;
    }

    // Here you would typically save the post to your backend
    toast.success('Hidden gem posted!');
    navigate('/posts');
  };

  const handleCancel = () => {
    navigate(-1);
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-background border-b border-border">
        <div className="flex items-center justify-between px-4 py-3">
          <button
            onClick={handleCancel}
            className="px-4 py-2 text-foreground hover:bg-accent rounded-lg transition-colors"
          >
            Cancel
          </button>
          <h1 className="absolute left-1/2 -translate-x-1/2">New Post</h1>
          <button
            onClick={handleSubmit}
            className="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90 transition-opacity"
          >
            Post
          </button>
        </div>
      </div>

      <div className="max-w-2xl mx-auto p-4">
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Image Upload */}
          <div>
            {imagePreview ? (
              <div className="relative">
                <img
                  src={imagePreview}
                  alt="Preview"
                  className="w-full h-80 object-cover rounded-lg"
                />
                <button
                  type="button"
                  onClick={handleRemoveImage}
                  className="absolute top-2 right-2 p-2 bg-background/80 backdrop-blur-sm rounded-full hover:bg-background transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            ) : (
              <label className="flex flex-col items-center justify-center w-full h-80 border-2 border-dashed border-border rounded-lg cursor-pointer hover:bg-accent/50 transition-colors">
                <ImageIcon className="w-12 h-12 text-muted-foreground mb-2" />
                <span className="text-muted-foreground">Add a photo</span>
                <input
                  type="file"
                  accept="image/*"
                  onChange={handleImageUpload}
                  className="hidden"
                />
              </label>
            )}
          </div>

          {/* Caption */}
          <div>
            <label htmlFor="caption" className="block mb-2">
              Caption
            </label>
            <textarea
              id="caption"
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              placeholder="Share what makes this place special..."
              className="w-full px-4 py-3 bg-input-background rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-ring"
              rows={4}
            />
          </div>

          {/* Location */}
          <div>
            <label htmlFor="location" className="block mb-2">
              Location
            </label>
            <div className="relative">
              <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                id="location"
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                placeholder="Where is this hidden gem?"
                className="w-full pl-12 pr-4 py-3 bg-input-background rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </div>
          </div>

          {/* Gem Type */}
          <div>
            <label className="block mb-2">Type of Hidden Gem</label>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {GEM_TYPES.map((type) => (
                <button
                  key={type.value}
                  type="button"
                  onClick={() => setSelectedType(type.value)}
                  className={`px-4 py-3 rounded-lg border transition-all ${
                    selectedType === type.value
                      ? 'bg-primary text-primary-foreground border-primary'
                      : 'bg-background border-border hover:bg-accent'
                  }`}
                >
                  {type.label}
                </button>
              ))}
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}
